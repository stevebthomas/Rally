import SwiftUI
import SwiftData
import UserNotifications

/// Main tab view for the app
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = 0

    init() {
        // Configure tab bar appearance with glass effect
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        tabBarAppearance.backgroundEffect = UIBlurEffect(style: .systemMaterial)
        tabBarAppearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.3)
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        // Configure navigation bar appearance - adapts to dark mode
        let navBarAppearance = UINavigationBarAppearance()
        navBarAppearance.configureWithDefaultBackground()
        navBarAppearance.backgroundColor = .systemBackground
        UINavigationBar.appearance().standardAppearance = navBarAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navBarAppearance
        UINavigationBar.appearance().compactAppearance = navBarAppearance
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            RecordWorkoutView()
                .tabItem {
                    Label("Record", systemImage: "mic.fill")
                }
                .tag(0)

            WorkoutHistoryView()
                .tabItem {
                    Label("History", systemImage: "calendar")
                }
                .tag(1)

            ProgressChartsView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(.rallyOrange)
    }
}

/// Settings view for API key configuration and profile
struct SettingsView: View {
    @AppStorage("openai_api_key") private var apiKey = ""
    @AppStorage("weight_unit") private var preferredUnit = WeightUnit.lbs.rawValue
    @AppStorage("userName") private var userName = ""
    @AppStorage("userBirthday") private var userBirthday: Double = Date().timeIntervalSince1970
    @AppStorage("userWeight") private var userWeight: Double = 0
    @AppStorage("userHeight") private var userHeight: Double = 0
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var showingAPIKeyField = false
    @State private var tempAPIKey = ""
    @State private var isValidating = false
    @State private var validationResult: Bool?
    @State private var weightText = ""

    private var birthdayBinding: Binding<Date> {
        Binding(
            get: { Date(timeIntervalSince1970: userBirthday) },
            set: { userBirthday = $0.timeIntervalSince1970 }
        )
    }

    private var heightFeetBinding: Binding<Int> {
        Binding(
            get: { Int(userHeight) / 12 },
            set: { userHeight = Double($0 * 12 + Int(userHeight) % 12) }
        )
    }

    private var heightInchesBinding: Binding<Int> {
        Binding(
            get: { Int(userHeight) % 12 },
            set: { userHeight = Double((Int(userHeight) / 12) * 12 + $0) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .textInputAutocapitalization(.words)
                    }

                    DatePicker("Birthday", selection: birthdayBinding, displayedComponents: .date)

                    HStack {
                        Text("Weight")
                        Spacer()
                        TextField("0", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                            .onChange(of: weightText) { _, newValue in
                                if let val = Double(newValue) {
                                    userWeight = val
                                }
                            }
                        Text("lbs")
                            .foregroundStyle(.secondary)
                    }

                    NavigationLink {
                        Form {
                            Picker("Feet", selection: heightFeetBinding) {
                                ForEach(3...7, id: \.self) { ft in
                                    Text("\(ft) ft").tag(ft)
                                }
                            }
                            .pickerStyle(.wheel)

                            Picker("Inches", selection: heightInchesBinding) {
                                ForEach(0...11, id: \.self) { inch in
                                    Text("\(inch) in").tag(inch)
                                }
                            }
                            .pickerStyle(.wheel)
                        }
                        .navigationTitle("Height")
                    } label: {
                        HStack {
                            Text("Height")
                            Spacer()
                            Text(userHeight > 0 ? "\(Int(userHeight) / 12)' \(Int(userHeight) % 12)\"" : "Not set")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Toggle("Daily Reminder", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, enabled in
                            if enabled {
                                NotificationService.shared.requestPermissionAndSchedule()
                            } else {
                                UNUserNotificationCenter.current()
                                    .removePendingNotificationRequests(withIdentifiers: ["daily_workout_reminder"])
                            }
                        }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("Get a daily workout reminder at 8 PM.")
                }

                Section {
                    HStack {
                        Text("OpenAI API Key")
                        Spacer()
                        if apiKey.isEmpty {
                            Text("Not set")
                                .foregroundColor(.red)
                        } else {
                            Text("••••••\(apiKey.suffix(4))")
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        tempAPIKey = apiKey
                        showingAPIKeyField = true
                    }
                } header: {
                    Text("API Configuration")
                } footer: {
                    Text("Your API key is stored securely on your device and used only to transcribe your voice recordings.")
                }

                Section("Preferences") {
                    Picker("Weight Unit", selection: $preferredUnit) {
                        Text("Pounds (lbs)").tag(WeightUnit.lbs.rawValue)
                        Text("Kilograms (kg)").tag(WeightUnit.kg.rawValue)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.1.0")
                            .foregroundColor(.secondary)
                    }

                    Link(destination: URL(string: "https://platform.openai.com/api-keys")!) {
                        HStack {
                            Text("Get OpenAI API Key")
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Settings")
                        .font(.headline)
                }
            }
            .onAppear {
                if weightText.isEmpty && userWeight > 0 {
                    weightText = String(format: "%g", userWeight)
                }
            }
            .sheet(isPresented: $showingAPIKeyField) {
                APIKeySheet(
                    apiKey: $tempAPIKey,
                    isValidating: $isValidating,
                    validationResult: $validationResult,
                    onSave: {
                        apiKey = tempAPIKey
                        showingAPIKeyField = false
                    },
                    onCancel: {
                        showingAPIKeyField = false
                    }
                )
            }
        }
    }
}

/// Sheet for entering API key
struct APIKeySheet: View {
    @Binding var apiKey: String
    @Binding var isValidating: Bool
    @Binding var validationResult: Bool?

    let onSave: () -> Void
    let onCancel: () -> Void

    private let whisperService = WhisperService()

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("sk-...", text: $apiKey)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("OpenAI API Key")
                } footer: {
                    if let result = validationResult {
                        HStack {
                            Image(systemName: result ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(result ? .green : .red)
                            Text(result ? "API key format looks valid" : "Invalid API key format")
                        }
                    }
                }
            }
            .navigationTitle("API Key")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isValidating = true
                            validationResult = await whisperService.validateAPIKey(apiKey)
                            isValidating = false
                            if validationResult == true {
                                onSave()
                            }
                        }
                    }
                    .disabled(apiKey.isEmpty || isValidating)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Workout.self, inMemory: true)
}
