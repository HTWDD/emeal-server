import Vapor

extension Droplet {
    func setupRoutes() throws {
        try resource("canteens", CanteenController.self)
        try resource("meals", MealController.self)

        get("search") { req in
            guard let query: String = try req.query?.get("query") else {
                throw Abort(.badRequest, reason: "Missing parameter `query`.")
            }

            Log.verbose("Searching for '\(query)'")

            return try Meal.makeQuery()
                .filter(Meal.Keys.title, .contains, query)
                .sort(Meal.Keys.date, .ascending)
                .all()
                .makeJSON()
        }

        post("update") { req in
            guard req.peerHostname == "0.0.0.0" else {
                throw Abort(.unauthorized)
            }
            
            guard
                let week = Week(rawString: try req.formURLEncoded?.get("week") ?? ""),
                let day = Day(rawString: try req.formURLEncoded?.get("day") ?? "")
            else {
                throw Abort(.badRequest)
            }

            Log.info("Update request for \(week) \(day)")

            let job = Job.menu(week: week, day: day)
            Updater.run(jobs: [job])

            return "Fetching data for \(week) \(day)..."
        }
    }
}
