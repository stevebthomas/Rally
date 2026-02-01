import SwiftUI

/// Card displaying an exercise with its sets
struct ExerciseCard: View {
    let exercise: Exercise
    var onEdit: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text(exercise.name)
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                if let onEdit = onEdit {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .foregroundColor(.rallyOrange)
                    }
                    .buttonStyle(.plain)
                }

                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Sets grid
            ForEach(exercise.sortedSets, id: \.id) { set in
                SetRow(set: set)
            }

            // Summary
            HStack {
                Label("\(exercise.totalReps) reps", systemImage: "repeat")
                Spacer()
                Label("\(Int(exercise.totalVolume)) \(exercise.sets.first?.unit.rawValue ?? "lbs") volume", systemImage: "scalemass")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Row displaying a single set
struct SetRow: View {
    let set: ExerciseSet

    var body: some View {
        HStack {
            Text("Set \(set.setNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            HStack(spacing: 16) {
                Label("\(set.reps)", systemImage: "arrow.counterclockwise")
                    .font(.subheadline)

                Label("\(Int(set.weight)) \(set.unit.rawValue)", systemImage: "scalemass.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Editable version of ExerciseCard for workout editing
struct EditableExerciseCard: View {
    @Binding var exercise: ParsedExercise
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise name
            HStack {
                TextField("Exercise name", text: $exercise.name)
                    .font(.headline)
                    .textFieldStyle(.plain)

                Button(action: onDelete) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
            }

            Divider()

            // Sets
            ForEach(exercise.sets.indices, id: \.self) { index in
                EditableSetRow(set: $exercise.sets[index], setNumber: index + 1) {
                    exercise.sets.remove(at: index)
                }
            }

            // Add set button
            Button {
                let newSet = ParsedSet(
                    setNumber: exercise.sets.count + 1,
                    reps: exercise.sets.last?.reps ?? 10,
                    weight: exercise.sets.last?.weight ?? 0,
                    unit: exercise.sets.last?.unit ?? .lbs
                )
                exercise.sets.append(newSet)
            } label: {
                Label("Add Set", systemImage: "plus.circle")
                    .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

/// Editable row for a single set
struct EditableSetRow: View {
    @Binding var set: ParsedSet
    let setNumber: Int
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Text("Set \(setNumber)")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Spacer()

            // Reps
            HStack(spacing: 4) {
                TextField("0", value: $set.reps, format: .number)
                    .keyboardType(.numberPad)
                    .frame(width: 40)
                    .textFieldStyle(.roundedBorder)
                Text("reps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Weight
            HStack(spacing: 4) {
                TextField("0", value: $set.weight, format: .number)
                    .keyboardType(.decimalPad)
                    .frame(width: 60)
                    .textFieldStyle(.roundedBorder)

                Picker("", selection: $set.unit) {
                    ForEach(WeightUnit.allCases, id: \.self) { unit in
                        Text(unit.rawValue).tag(unit)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
    }
}

/// Compact exercise summary for list views
struct ExerciseListItem: View {
    let exercise: Exercise

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)

                Text(exercise.summary)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 16) {
            ExerciseCard(
                exercise: {
                    let ex = Exercise(name: "Bench Press")
                    ex.sets = [
                        ExerciseSet(setNumber: 1, reps: 10, weight: 135),
                        ExerciseSet(setNumber: 2, reps: 8, weight: 155),
                        ExerciseSet(setNumber: 3, reps: 6, weight: 175)
                    ]
                    return ex
                }(),
                onEdit: {},
                onDelete: {}
            )

            ExerciseListItem(
                exercise: {
                    let ex = Exercise(name: "Squats")
                    ex.sets = [
                        ExerciseSet(setNumber: 1, reps: 10, weight: 185),
                        ExerciseSet(setNumber: 2, reps: 8, weight: 205)
                    ]
                    return ex
                }()
            )
        }
        .padding()
    }
}
