import SwiftUI

/// 已读回执指示器
struct ReadReceiptIndicator: View {
    let message: ChatMessage
    let showDetails: Bool
    
    var body: some View {
        if message.hasReadReceipts {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.blue)
                
                if showDetails {
                    Text("\(message.readCount) 人已读")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

/// 已读回执详情视图
struct ReadReceiptDetailView: View {
    @Environment(\.dismiss) var dismiss
    let message: ChatMessage
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(message.readReceipts.sorted(by: { $0.timestamp > $1.timestamp }), id: \.id) { receipt in
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(receipt.userId)
                                    .font(.body)
                                Text(receipt.timestamp, style: .relative)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("已读 (\(message.readCount))")
                }
            }
            .navigationTitle("消息回执")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReadReceiptDetailView(message: ChatMessage(
        id: "1",
        channel: "test",
        sender: "Alice",
        text: "Hello",
        readReceipts: [
            ReadReceipt(messageId: "1", userId: "Bob"),
            ReadReceipt(messageId: "1", userId: "Charlie", timestamp: Date().addingTimeInterval(-60))
        ]
    ))
}

