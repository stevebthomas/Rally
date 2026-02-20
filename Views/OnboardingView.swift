import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("userName") private var userName = ""
    @AppStorage("userBirthday") private var userBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userHeight") private var userHeight: Double = 0

    @State private var step = 0
    @State private var nameInput = ""
    @State private var birthdayInput = Date()
    @State private var weightInput = ""
    @State private var heightFeet = 5
    @State private var heightInches = 8

    private let totalSteps = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack(spacing: 6) {
                ForEach(0..<totalSteps, id: \.self) { i in
                    Capsule()
                        .fill(i <= step ? Color.rallyOrange : Color.secondary.opacity(0.3))
                        .frame(height: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)

            Spacer()

            // Step content
            Group {
                switch step {
                case 0: nameStep
                case 1: birthdayStep
                case 2: weightStep
                case 3: heightStep
                default: EmptyView()
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            // Action button
            Button {
                advance()
            } label: {
                Text(step < totalSteps - 1 ? "Next" : "Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(canAdvance ? Color.rallyOrange : Color.rallyOrange.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canAdvance)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
        .background(Color.appBackground.ignoresSafeArea())
        .animation(.easeInOut(duration: 0.3), value: step)
    }

    // MARK: - Steps

    private var nameStep: some View {
        VStack(spacing: 16) {
            Text("What's your name?")
                .font(.title.bold())
            TextField("Name", text: $nameInput)
                .font(.title2)
                .multilineTextAlignment(.center)
                .textInputAutocapitalization(.words)
                .submitLabel(.next)
                .onSubmit { if canAdvance { advance() } }
        }
    }

    private var birthdayStep: some View {
        VStack(spacing: 16) {
            Text("When's your birthday?")
                .font(.title.bold())
            DatePicker("Birthday", selection: $birthdayInput, displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
        }
    }

    private var weightStep: some View {
        VStack(spacing: 16) {
            Text("What's your weight?")
                .font(.title.bold())
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                TextField("0", text: $weightInput)
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .frame(width: 140)
                Text("lbs")
                    .font(.title2)
                    .foregroundStyle(Color.secondaryText)
            }
        }
    }

    private var heightStep: some View {
        VStack(spacing: 16) {
            Text("How tall are you?")
                .font(.title.bold())
            HStack(spacing: 0) {
                Picker("Feet", selection: $heightFeet) {
                    ForEach(3...7, id: \.self) { ft in
                        Text("\(ft) ft").tag(ft)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 120)

                Picker("Inches", selection: $heightInches) {
                    ForEach(0...11, id: \.self) { inch in
                        Text("\(inch) in").tag(inch)
                    }
                }
                .pickerStyle(.wheel)
                .frame(width: 120)
            }
            .frame(height: 150)
        }
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case 0: return !nameInput.trimmingCharacters(in: .whitespaces).isEmpty
        case 2: return Double(weightInput) != nil && Double(weightInput)! > 0
        default: return true
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            step += 1
        } else {
            saveAndFinish()
        }
    }

    private func saveAndFinish() {
        userName = nameInput.trimmingCharacters(in: .whitespaces)
        userBirthday = birthdayInput.timeIntervalSince1970
        userWeight = Double(weightInput) ?? 0
        userHeight = Double(heightFeet * 12 + heightInches)
        NotificationService.shared.requestPermissionAndSchedule()
        hasCompletedOnboarding = true
    }
}
