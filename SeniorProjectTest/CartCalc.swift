//
//  CartCalc.swift
//  SeniorProjectTest
//
//  Created by Gabriella Huegel on 3/24/24.
//

import SwiftUI


struct CartCalc: View {
    @EnvironmentObject var viewModel: LoginController
    @State private var showError = false
    @State private var navigateToComparison = false
    
    var body: some View {
        NavigationView {
            VStack {
                List(viewModel.calculationOrder) { item in
                    CartRow(item: item)
                }
                
                // Calculate button
                Button(action: {
                    if !viewModel.calculationOrder.isEmpty {
                        //viewModel.addPoints(username: viewModel.email)
                        // Trigger navigation
                        navigateToComparison = true
                    } else {
                        showError = true
                    }
                }) {
                    Text("Calculate")
                        .font(.subheadline)
                        .foregroundColor(.white)
                        .frame(width: 100, height: 50)
                        .background(Color.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding()
                
                // NavigationLink to ComparisonCalc
                NavigationLink(
                    destination: ComparisonCalc(viewModel: _viewModel, item_list: viewModel.calculationOrder),
                    isActive: $navigateToComparison,
                    label: { EmptyView() }
                )
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text("Calculation order is empty!"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationTitle("Cart Calculation")
        }
    }
}

struct CartCalc_Previews: PreviewProvider {
    static var previews: some View {
        CartCalc().environmentObject(LoginController())
    }
}

