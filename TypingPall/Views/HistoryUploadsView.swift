//
//  HistoryUploadsView.swift
//  TypingPall
//
//  Created by Mieraidihaimu Mieraisan on 13/07/2023.
//

import SwiftUI
import CoreData

struct HistoryUploadsView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Item.timestamp, ascending: true)],
        animation: .default)
    private var items: FetchedResults<Item>

    @Binding var placeholderText: String
    @Binding var isShowingHistoryUploads: Bool

    var body: some View {
        NavigationView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        VStack {
                            HStack {
                                Spacer()
                                Button("Use this text!") {
                                    placeholderText = item.text ?? ""
                                    isShowingHistoryUploads.toggle()
                                }
                            }
                            TextEditor(text: .constant(item.text ?? ""))
                                .disabled(true)
                        }
                        .padding(.all)
                    } label: {
                        VStack(alignment: .leading) {
                            Text(item.text?.prefix(44) ?? "")
                                .lineLimit(1)
                                .font(.body)

                            Text("\(item.timestamp!, formatter: itemFormatter)")
                                .font(.caption2)
                                .italic()
                        }
                        .frame(minWidth: 80)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            Text("Select an item")
        }.toolbar {
            ToolbarItem {
                Button("Dismiss") {
                    isShowingHistoryUploads.toggle()
                }
            }
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            offsets.map { items[$0] }.forEach(viewContext.delete)

            do {
                try viewContext.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter
}()

struct HistoryUploadsView_Previews: PreviewProvider {
    static var previews: some View {
        HistoryUploadsView(placeholderText: .constant("Hello World"), isShowingHistoryUploads: .constant(true))
    }
}
