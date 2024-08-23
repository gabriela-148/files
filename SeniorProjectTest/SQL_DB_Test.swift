//
//  SQL_DB_Test.swift
//  SeniorProjectTest
//
//  Created by Gabriella Huegel on 2/24/24.
//

import Foundation
import SQLite
import UIKit

// Code gotten from GitHub
enum SideMenuOptionModel: Int, CaseIterable {
    case dashboard
    case pickTwo
    case burgers
    case settings
    
    var title: String {
        switch self {
        case .dashboard:
            return "Dashboard"
        case .pickTwo:
            return "Pick Two"
        case .burgers:
            return "Burgers"
        case .settings:
            return "Settings"
        }
    }
    
    var systemImageName: String {
        switch self {
        case .dashboard:
            return "house"
        case .pickTwo:
            return "2.square"
        case .burgers:
            return "fork.knife"
        case .settings:
            return "gear"
        }
    }
}
extension SideMenuOptionModel: Identifiable {
    var id: Int { return self.rawValue }
}

class LoginController: ObservableObject {
    
    // Variables to be changed with database calls in funcitons below
    @Published var isSignedIn = false // changes view in real time
    @Published var name = ""
    @Published var email = ""
    @Published var userPoints = 0// resets user points to 0 after each login - need to figure out how to save in program - ik its saved in DB
    
    @Published var foodList = [Food_Item]()
    @Published var calculationOrder = [Food_Item]()
    @Published var userList = [User]()
    
    @Published var currID: Int = -1
    
    
    func getUserPoints(email: String) {
        
        do {
            // Path to the SQLite database file
            let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
            
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define the table and columns
            let users = Table("usersList")
            let storedUsername = Expression<String>("email")
            let storedPoints = Expression<Int>("totalPoints")
            
            // Construct the query to select points for the specified email
            let pointsQuery = users.select(storedPoints).filter(storedUsername == email)
            
            // Execute the query and try to fetch the user's points
            if let user = try db.pluck(pointsQuery) {
                // User found, retrieve the points value
                self.userPoints = try user.get(storedPoints)
                print("Current points: \(self.userPoints)")
                
            } else {
                // User not found, print an error message
                print("User with email '\(email)' not found")
            }
        } catch {
            // Handle any errors that occur during database operations
            print("Error: \(error)")
        }
        
    }


    func addPoints(username: String) {
        guard !calculationOrder.isEmpty else {
            print("Calculation cart is empty!")
            return
        }

        // Fetch the user ID for the given username
        fetchUserId(for: username) { userId in
            guard let userId = userId else {
                print("User not found!")
                return
            }
            
            // Initialize a variable to hold total points
            var totalPoints = 0
            
            // Use a dispatch group to wait for all API calls to complete
            let dispatchGroup = DispatchGroup()
            
            for item in self.calculationOrder {
                let name = item.name
                let weight = item.weight
                
                dispatchGroup.enter()
                
                // Call the API to get points for each item
                self.calculatePointsFromAPI(name: name, weight: weight, userId: userId) { points in
                    if let points = points {
                        totalPoints += points
                    } else {
                        print("Failed to get points for \(name)")
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // After all API calls are complete, update the user's points in the database
                self.updateUserPoints(username: username)
            }
        }
    }

    // Function to call API and get points
    private func calculatePointsFromAPI(name: String, weight: Double, userId: Int, completion: @escaping (Int?) -> Void) {
        let urlString = "http://<173.72.41.229>:8080/api/footprint?name=\(name)&weight=\(weight)&id=\(userId)"
        guard let url = URL(string: urlString) else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API request error: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data else {
                completion(nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let points = json["points"] as? Int {
                    completion(points)
                } else {
                    completion(nil)
                }
            } catch {
                print("Error parsing JSON: \(error)")
                completion(nil)
            }
        }
        
        task.resume()
    }
    
    /// Function to fetch the current points for a user from the API
    private func fetchUserPoints(userId: Int, completion: @escaping (Int?) -> Void) {
        let urlString = "http://<173.72.41.229>:8080/api/get_points?id=\(userId)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL for fetching points")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("API request error for fetching points: \(error)")
                completion(nil)
                return
            }
            
            guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                  let points = json["points"] as? Int else {
                print("Failed to get points from API")
                completion(nil)
                return
            }
            
            completion(points)
        }
        
        task.resume()
    }

    // Function to update user points using the API
    private func updateUserPoints(username: String) {
        guard !calculationOrder.isEmpty else {
            print("Calculation cart is empty!")
            return
        }
        
        // Fetch the user ID for the given username
        fetchUserId(for: username) { userId in
            guard let userId = userId else {
                print("User not found!")
                return
            }
            
            // Create a dispatch group to wait for all API calls to complete
            let dispatchGroup = DispatchGroup()
            
            // Iterate through items in the cart
            for item in self.calculationOrder {
                // Enter the dispatch group
                dispatchGroup.enter()
                
                let urlString = "http://<173.72.41.229>:8080/api/footprint?name=\(item.name)&weight=\(item.weight)&id=\(userId)"
                guard let url = URL(string: urlString) else {
                    print("Invalid URL for item \(item.name)")
                    dispatchGroup.leave()
                    continue
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                
                let task = URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        print("API request error for item \(item.name): \(error)")
                        dispatchGroup.leave()
                        return
                    }
                    
                    guard let data = data, let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                          let pointsFromApi = json["points"] as? Int else {
                        print("Failed to get points from API for item \(item.name)")
                        dispatchGroup.leave()
                        return
                    }
                    
                    // Fetch current points and then add the points for the selected burger
                    self.fetchUserPoints(userId: userId) { currentPoints in
                        guard let currentPoints = currentPoints else {
                            print("Failed to fetch current points")
                            dispatchGroup.leave()
                            return
                        }
                        
                        let newTotalPoints = currentPoints + pointsFromApi
                        
                        // Prepare the URL and request for updating points
                        let updateUrlString = "http://<173.72.41.229>:8080/api/update_points?id=\(userId)&points=\(pointsFromApi)"
                        guard let updateUrl = URL(string: updateUrlString) else {
                            print("Invalid URL for updating points")
                            dispatchGroup.leave()
                            return
                        }
                        
                        var updateRequest = URLRequest(url: updateUrl)
                        updateRequest.httpMethod = "GET"
                        
                        let updateTask = URLSession.shared.dataTask(with: updateRequest) { data, response, error in
                            if let error = error {
                                print("API request error for updating points: \(error)")
                                dispatchGroup.leave()
                                return
                            }
                            
                            guard let response = response as? HTTPURLResponse, response.statusCode == 200 else {
                                print("Failed to update points")
                                dispatchGroup.leave()
                                return
                            }
                            
                            DispatchQueue.main.async {
                                self.userPoints = newTotalPoints  // Update the published property
                                print("Points updated successfully for user \(username)")
                            }
                            
                            dispatchGroup.leave()
                        }
                        
                        updateTask.resume()
                    }
                }
                
                task.resume()
            }
            
            // Notify when all API calls are complete
            dispatchGroup.notify(queue: .main) {
                print("All points updates completed")
            }
        }
    }

    // Function to fetch user ID based on username
    private func fetchUserId(for username: String, completion: @escaping (Int?) -> Void) {
        // Your logic to fetch user ID from database based on username
        // For demonstration, returning a mock user ID
        completion(0)  // Replace with actual logic
    }



    // Adds item to cart
    func addToCalc(item: Food_Item) {
        calculationOrder.append(item)
    }
    
    // Removes item from cart
    func removeFromCalc(item: Food_Item) {
        calculationOrder.removeAll { $0 == item }
    }
    
    // Signs out user in real time
    func signOut() {
        self.isSignedIn = false
    }
    
    // Returns the email String of the current user logged in
    func getEmailOfUser() -> String? {
        do {
            // Path to the SQLite database file
            let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
            
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define the table and column
            let users = Table("usersList")
            let emailColumn = Expression<String>("email")
            
            // Fetch the first row from the 'usersList' table
            if let user = try db.pluck(users.select(emailColumn)) {
                // Extract and return the email from the row
                return try user.get(emailColumn)
            } else {
                // If no row is found, return nil
                return nil
            }
        } catch {
            // Handle any errors that occur during database operations
            print("Error: \(error)")
            return nil
        }
    }

    // Changes the password for the current user as long as their old pwd matches
    func resetPassword(username: String, newPassword: String, oldPassword: String) -> Bool {
        var success = false
        // Path to the SQLite database file
        let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
        do {
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            let users = Table("usersList")
            let storedUsername = Expression<String>("email")
            let storedPassword = Expression<String>("password")
            
            let userQuery = users.filter(username == storedUsername && storedPassword == oldPassword)
            
                
            if let user = try db.pluck(userQuery) {
                let updateUser = users.filter(username == storedUsername)
                        .update(storedPassword <- newPassword)
                try db.run(updateUser)
                
                success = true
            }
            
            
        } catch {
            print("Error: \(error)")
        }
        return success
    }
    
    // Checks the input in the user database to login the user to the app
    func login(username: String, password: String) -> Bool {
        var success = true
        
        // Path to the SQLite database file
        let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
        do {
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            let users = Table("usersList")
            let storedUsername = Expression<String>("email")
            let storedID = Expression<Int>("id")
            let storedPassword = Expression<String>("password")
            let storedName = Expression<String>("name")
            let storedPoints = Expression<Int>("totalPoints")
            
            let query = users.select(storedName)
                .filter(storedUsername == username && storedPassword == password)
            
            let emailQuery = users.select(storedUsername)
            
            let pointsQuery = users.select(storedPoints)
            
            if let user = try db.pluck(query) {
                // Login successful
                success = true
                
                self.isSignedIn = true
                self.name = user[storedName]
                self.email = getEmailOfUser() ?? "testing"
                
                // Call calcFootprints to update food items
                calcFootprints {
                    // Fetch updated food items
                    self.foodList = self.fetchFoodItems()
                    
                    // Fetch user data
                    self.userList = (try? db.prepare(users).map { item in
                        User(name: item[storedName],
                             email: item[storedUsername],
                             pwd: item[storedPassword],
                             id: item[storedID],
                             points: item[storedPoints])
                    }) ?? []
                }
                
            }
            
            if let user2 = try db.pluck(emailQuery) {
                success = true
                self.email = user2[storedUsername]
            }
            
            if let user3 = try db.pluck(pointsQuery) {
                success = true
                self.userPoints = user3[storedPoints]
            }
            
        } catch {
            print("Error: \(error)")
        }
        return success
    }


    
    //function to get weights in db
    func getWeights() {
        // Define your SQLite database connection
        do {
        let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
        let db = try Connection(dbPath)

        // Define table structure and columns
        let food_items = Table("food")
        let storedWeight = Expression<Double>("weight") // Assuming the 'weight' column is of type REAL in SQLite

        
            // Fetch a single row from the 'food_items' table
            for item in try db.prepare(food_items) {
                // Retrieve the 'weight' column value and cast it to Double
                let weight: Double = try item.get(storedWeight)
                
                // Now 'weight' contains the value of the 'weight' column as a Double
                print("Weight: \(weight)")
            }
        } catch {
            print("Error: \(error)")
        }
    }
    // Function to fetch rows from SQLite database and store them in a list
    func fetchFoodItems() -> [Food_Item] {
        var foodItemList = [Food_Item]()
        
        do {
            // Path to the SQLite database file
            guard let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db") else {
                print("Database path not found.")
                return foodItemList
            }
            
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define table structure and columns
            let foodItems = Table("food")
            let storedFoodName = Expression<String>("name")
            let storedRestaurant = Expression<String>("restaurant")
            let storedWeight = Expression<Double>("weight")
            let storedCarbon = Expression<Double>("carbonFP")
            let storedWater = Expression<Double>("waterFP")
            let storedPoints = Expression<Double>("pointValue")
            
            // Fetch all rows from the 'food_items' table
            for item in try db.prepare(foodItems) {
                // Create Food_Item instance for each row and append to foodItemList
                let foodItem = Food_Item(name: item[storedFoodName],
                                         rest: item[storedRestaurant],
                                         weight: item[storedWeight],
                                         id: item[storedPoints],
                                         imageName: item[storedFoodName],
                                         carbonFP: item[storedCarbon],
                                         waterFP: item[storedWater])
                foodItemList.append(foodItem)
            }
        } catch {
            print("Error: \(error)")
        }
        return foodItemList
    }


    /// Function to fetch carbon and water footprint from the API
    func fetchFootprintData(name: String, weight: Double, userId: Int, completion: @escaping (Food_Item) -> Void) {
        let urlString = "http://<173.72.41.229>:8080/api/footprint?name=\(name)&weight=\(weight)&user_id=\(userId)"
        guard let url = URL(string: urlString) else { return }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else {
                print("API request error: \(String(describing: error))")
                return
            }
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Double] {
                    let carbon = json["carbon"] ?? 0.0
                    let water = json["water"] ?? 0.0
                    
                    print("API Response - Carbon: \(carbon), Water: \(water)")
                    
                    let foodItem = Food_Item(name: name, rest: "", weight: weight, id: 0, imageName: "", carbonFP: carbon, waterFP: water)
                    
                    DispatchQueue.main.async {
                        completion(foodItem)
                    }
                }
            } catch {
                print("Error parsing JSON: \(error)")
            }
        }
        task.resume()
    }


    // Calculates both carbon and water footprints for items in the database
    func calcFootprints(completion: @escaping () -> Void) {
        do {
            // Path to the SQLite database file
            guard let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db") else {
                print("Database path not found.")
                return
            }
            
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define table structure and columns
            let foodItems = Table("food")
            let storedCarbon = Expression<Double>("carbonFP")
            let storedWater = Expression<Double>("waterFP")
            let storedFoodName = Expression<String>("name")
            let storedWeight = Expression<Double>("weight")
            
            // Define the users table and columns
            let users = Table("usersList")
            let userID = Expression<Int>("id")  // Define the user ID column
            
            // Fetch all rows from the 'food' table
            let items = try db.prepare(foodItems)
            
            // Fetch the user ID from the 'usersList' table
            let userQuery = users.select(userID)
            guard let userRow = try db.pluck(userQuery) else {
                print("No user found.")
                return
            }
            let userIdValue = userRow[userID]  // Extract the user ID value
            
            let dispatchGroup = DispatchGroup()
            
            // Dictionary to hold updated food items
            var updatedFoodItems = [String: Food_Item]()
            
            for item in items {
                let name = try item.get(storedFoodName)
                let weight = try item.get(storedWeight)
                
                dispatchGroup.enter()
                
                // Fetch carbon and water footprint using API
                fetchFootprintData(name: name, weight: weight, userId: userIdValue) { foodItem in
                    // Update the database with the fetched values
                    let updateQuery = foodItems.filter(storedFoodName == foodItem.name)
                        .update(storedCarbon <- foodItem.carbonFP, storedWater <- foodItem.waterFP)
                    
                    do {
                        try db.run(updateQuery)
                        print("Database updated for \(foodItem.name): Carbon FP \(foodItem.carbonFP), Water FP \(foodItem.waterFP)")
                        
                        // Store the updated food item
                        updatedFoodItems[foodItem.name] = foodItem
                    } catch {
                        print("Error updating database: \(error)")
                    }
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                // Update the foodList with new values
                self.foodList = self.foodList.map { item in
                    if let updatedItem = updatedFoodItems[item.name] {
                        return updatedItem
                    } else {
                        return item
                    }
                }
                completion()
            }
            
        } catch {
            print("Error: \(error)")
            // Notify completion even if there was an error
            completion()
        }
        
        
    }

    // Function to fetch the current value of totalPoints from the userList table
    func fetchTotalPoints(forUserId userId: Int, completion: @escaping (Int?) -> Void) {
        // Path to the SQLite database file
        guard let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db") else {
            print("Database path not found.")
            completion(nil)
            return
        }
        
        do {
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define the userList table and columns
            let userList = Table("userList")
            let userIdColumn = Expression<Int>("id")
            let totalPointsColumn = Expression<Int>("totalPoints")
            
            // Create a query to fetch the totalPoints for the specific userId
            let query = userList.filter(userIdColumn == userId).select(totalPointsColumn)
            
            // Execute the query
            if let userRow = try db.pluck(query) {
                let totalPoints = userRow[totalPointsColumn]
                print("Total points for user \(userId): \(totalPoints)")
                completion(totalPoints)
            } else {
                print("User not found.")
                completion(nil)
            }
        } catch {
            print("Error: \(error)")
            completion(nil)
        }
    }



    // Returns all the records in the tables in teh database
    func getAllTables() {
        // Path to the SQLite database file
        let dbPath = Bundle.main.path(forResource: "mydatabase", ofType: "db")!
        
        do {
            // Establish a connection to the SQLite database
            let db = try Connection(dbPath)
            
            // Define table structure and columns
            let users = Table("usersList")
            let name = Expression<String>("name")
            let items = Table("food_items")
            let food_name = Expression<String>("name")
            
            // Fetch all rows from the 'users' table and print them to the console
            for user in try db.prepare(users) {
                print("Name: \(user[name])")
            }
            for item in try db.prepare(items) {
                print("Item: \(item[food_name])")
            }
        } catch {
            print("Error: \(error)")
        }
    }// end get all tables func
}//end of class
