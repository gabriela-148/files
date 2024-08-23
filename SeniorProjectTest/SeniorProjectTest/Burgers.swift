//
//  Burgers.swift
//  SeniorProjectTest
//
//  Created by Gabriella Huegel on 3/23/24.
//

import SwiftUI

struct Burgers: View {
    // Envi object so can have access to database calls
    @EnvironmentObject var viewModel: LoginController

    var body: some View {
        VStack {
            Section {
                // Lists out burgers in a scrollable list
                List(viewModel.foodList){ item in
                    NavigationLink(destination: InfoScreenView(foodItem: item)) {
                        InfoRow(item: item)
                    }
                    
                }//list
            }//section
            //.searchable(text: $searchText, prompt: "Enter a name") /for later
            
        }// vstack
    }
}

#Preview {
    Burgers()
}
