import SwiftUI
import UserNotifications

struct Reminder: Identifiable {
    var id = UUID()
    var title: String
    var description: String
    var dueDate: Date
    var icon: String
}

struct ContentView: View {
    @State private var reminders: [Reminder] = []
    @State private var showingAddReminder = false

    var body: some View {
        NavigationView {
            List {
                ForEach(reminders) { reminder in
                    if reminder.dueDate > Date() {
                        NavigationLink(destination: ReminderDetailView(reminder: reminder, reminders: $reminders)) {
                            VStack(alignment: .leading) {
                                Text("\(reminder.icon) \(reminder.title)")
                                    .font(.headline)
                                Text("Due: \(reminder.dueDate, formatter: dateFormatter)")
                                    .font(.subheadline)
                            }
                        }
                    }
                }
                .onDelete(perform: deleteReminder)
                .onMove(perform: moveReminder)
            }
            .navigationTitle("Reminders")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        showingAddReminder = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button("Edit") {
                        showingAddReminder = true
                    }
                }
            }
            .sheet(isPresented: $showingAddReminder) {
                AddReminderView(reminders: $reminders)
                    .onDisappear {
                        reminders.sort { $0.dueDate < $1.dueDate }
                    }
            }
        }
        .onAppear {
            requestNotificationPermission()
            observeNotificationCompletion()
        }
    }

    private func deleteReminder(at offsets: IndexSet) {
        let idsToRemove = offsets.map { reminders[$0].id.uuidString }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToRemove)
        reminders.remove(atOffsets: offsets)
    }

    private func moveReminder(from source: IndexSet, to destination: Int) {
        reminders.move(fromOffsets: source, toOffset: destination)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Error requesting notification permission: \(error)")
            }
        }
    }

    private func observeNotificationCompletion() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let currentIds = requests.map { $0.identifier }
            DispatchQueue.main.async {
                self.reminders.removeAll { !currentIds.contains($0.id.uuidString) }
            }
        }
    }
}

struct AddReminderView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var reminders: [Reminder]
    @State private var newReminderTitle: String = ""
    @State private var newReminderDescription: String = ""
    @State private var newReminderDate: Date = Date()
    @State private var selectedIcon: String = "🔔"

    let icons = ["🔔", "📅", "⏰", "📝", "📌"]

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Reminder Details")) {
                    TextField("Title", text: $newReminderTitle)
                    TextField("Description", text: $newReminderDescription)
                    DatePicker("Due Date", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                    Picker("Icon", selection: $selectedIcon) {
                        ForEach(icons, id: \.self) { icon in
                            Text(icon).tag(icon)
                        }
                    }
                }
                Section {
                    Button("Add Reminder") {
                        addReminder()
                    }
                }
            }
            .padding()
            .navigationTitle("New Reminder")
        }
    }

    private func addReminder() {
        let newReminder = Reminder(title: newReminderTitle, description: newReminderDescription, dueDate: newReminderDate, icon: selectedIcon)
        reminders.append(newReminder)
        scheduleNotification(for: newReminder)
        presentationMode.wrappedValue.dismiss()
    }

    private func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "\(reminder.icon) \(reminder.title) - Reminder due"
        content.body = "Your reminder is due!"
        content.sound = UNNotificationSound.default

        let triggerDate = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.dueDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: triggerDate, repeats: false)
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
}

struct ReminderDetailView: View {
    var reminder: Reminder
    @Binding var reminders: [Reminder]
    @State private var showingEditReminder = false
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("\(reminder.icon) \(reminder.title)")
                .font(.largeTitle)
                .padding(.bottom)
            Text(reminder.description)
                .font(.body)
                .padding(.bottom)
            Text("Due: \(reminder.dueDate, formatter: dateFormatter)")
                .font(.subheadline)
                .padding(.bottom)
            Spacer()
            HStack {
                Button("Edit") {
                    showingEditReminder = true
                }
                .padding()
                .sheet(isPresented: $showingEditReminder) {
                    EditReminderView(reminder: reminder, reminders: $reminders)
                }
                Button("Cancel") {
                    cancelReminder()
                }
                .padding()
            }
        }
        .padding()
        .navigationTitle("Reminder Details")
    }
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    private func cancelReminder() {
        if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders.remove(at: index)
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
        }
    }
    
    
    struct EditReminderView: View {
        var reminder: Reminder
        @Binding var reminders: [Reminder]
        @Environment(\.presentationMode) var presentationMode
        @State private var newReminderTitle: String
        @State private var newReminderDescription: String
        @State private var newReminderDate: Date
        @State private var selectedIcon: String
        
        init(reminder: Reminder, reminders: Binding<[Reminder]>) {
            self.reminder = reminder
            self._reminders = reminders
            self._newReminderTitle = State(initialValue: reminder.title)
            self._newReminderDescription = State(initialValue: reminder.description)
            self._newReminderDate = State(initialValue: reminder.dueDate)
            self._selectedIcon = State(initialValue: reminder.icon)
        }
        
        let icons = ["🔔", "📅", "⏰", "📝", "📌"]
        
        var body: some View {
            NavigationView {
                Form {
                    Section(header: Text("Reminder Details")) {
                        TextField("Title", text: $newReminderTitle)
                        TextField("Description", text: $newReminderDescription)
                        DatePicker("Due Date", selection: $newReminderDate, displayedComponents: [.date, .hourAndMinute])
                        Picker("Icon", selection: $selectedIcon) {
                            ForEach(icons, id: \.self) { icon in
                                Text(icon).tag(icon)
                            }
                        }
                    }
                    Section {
                        Button("Save Changes") {
                            saveChanges()
                            presentationMode.wrappedValue.dismiss()
                        }
                    }
                }
                .padding()
                .navigationTitle("Edit Reminder")
            }
        }
        
        private func saveChanges() {
            if let index = reminders.firstIndex(where: { $0.id == reminder.id }) {
                reminders[index].title = newReminderTitle
                reminders[index].description = newReminderDescription
                reminders[index].dueDate = newReminderDate
                reminders[index].icon = selectedIcon
                UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [reminder.id.uuidString])
                scheduleNotification(for: reminders[index])
            }
        }
        
        private func scheduleNotification(for reminder: Reminder) {
            let content = UNMutableNotificationContent()
            content.title = "\(reminder.icon) \(reminder.title) - Reminder due"
            content.body = "Your reminder is due!"
            content.sound = UNNotificationSound.default
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: reminder.dueDate.timeIntervalSinceNow, repeats: false)
            let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("Error scheduling notification: \(error)")
                }
            }
        }
    }
}

@main
struct ReminderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            SidebarCommands()
            CommandMenu("Actions") {
                Button(action: {
                    // Add action here
                }) {
                    Text("New Reminder")
                }
                .keyboardShortcut("N", modifiers: [.command])
            }
        }
    }
}
