import SwiftUI

struct AudioInputSelectorView: View {
    let inputManager: AudioInputManager

    var body: some View {
        HStack {
            Text("Audio Input")
                .font(.headline)

            Spacer()

            Picker("Audio Input", selection: selectedInputBinding) {
                ForEach(inputManager.availableInputNames, id: \.self) { inputName in
                    Text(inputName)
                        .tag(inputName)
                }
            }
            .labelsHidden()
            .frame(width: 240)
        }
        .padding()
        .background(.quaternary.opacity(0.45), in: RoundedRectangle(cornerRadius: 8))
    }

    private var selectedInputBinding: Binding<String> {
        Binding(
            get: {
                inputManager.selectedInputName
            },
            set: { inputName in
                inputManager.selectInput(named: inputName)
            }
        )
    }
}
