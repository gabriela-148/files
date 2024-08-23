import SwiftUI

struct InfoScreenView: View {
    let foodItem: Food_Item // FoodItem object passed from the previous screen
    
    // Computed properties for carbon and water values
    private var carbonValue: CGFloat {
        foodItem.carbonFP
    }
    
    private var waterValue: CGFloat {
        foodItem.waterFP
    }
    
    // Compute the combined value based on the carbon and water values
    private var combinedValue: CGFloat {
        (carbonValue + waterValue) / 2
    }
    
    var body: some View {
        VStack {
            HStack {
                CircleMetricView(title: "Carbon", value: carbonValue, color: (Color(red: 128/255, green: 0/255, blue: 32/255)) /* burgyundy in hex*/)
                Spacer()
                CircleMetricView(title: "\(Int(combinedValue * 100))", value: combinedValue, color: Color.indigo)
                Spacer()
                CircleMetricView(title: "Water", value: waterValue, color: Color.blue)
            }
            .padding(.horizontal, 40)
            
            Image(foodItem.imageName.lowercased())//need to change to item.imageName and store link to DB
                .resizable()
                .frame(width: 110, height: 110, alignment: .center)
            Text(foodItem.name)
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 20)
            
            Text("(meat only)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            VStack(alignment: .leading, spacing: 20) {
                InfoDetailView(label: "Weight", value: "\(foodItem.weight) g")
                InfoDetailView(label: "Water Bottles Consumed", value: "\(String(format: "%.f", foodItem.waterFP/0.5)) bottles")
                InfoDetailView(label: "Gallons of Gas Burned", value: "\(foodItem.carbonFP/20) gal")
            }
            .padding(.top, 30)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
}

struct CircleMetricView: View {
    var title: String
    var value: CGFloat // Value should be between 0 and 1
    var color: Color
    
    var body: some View {
        VStack {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: value) // Adjust the fraction to represent progress dynamically
                    .stroke(Color.blue, lineWidth: 8)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.5), value: value) // Animate changes
                
                Text(String(format: "%.0f%%", value * 100))
                    .font(.title)
                    .fontWeight(.bold)
            }
            Text(title)
                .font(.headline)
                .padding(.top, 5)
        }
    }
}

struct InfoDetailView: View {
    var label: String
    var value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.headline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }
}

struct InfoScreenView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleFoodItem = Food_Item(name: "Big Mac", rest:"McDonalds", weight: 90.8, id: 1, imageName: "Big Mac", carbonFP: 0.4, waterFP: 0.6)
        InfoScreenView(foodItem: sampleFoodItem)
    }
}
