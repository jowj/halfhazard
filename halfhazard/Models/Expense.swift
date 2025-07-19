//
//  Expense.swift
//  halfhazard
//
//  Created by Josiah Ledbetter on 2025-01-13.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Expense: Codable, Identifiable, Hashable {
    let id: String
    var amount: Double
    var description: String?
    let groupId: String
    var createdBy: String
    let createdAt: Timestamp
    var splitType: SplitType
    var splits: [String: Double]
    var customSplitPercentages: [String: Double]? // Stores percentage splits for custom split type
    var payments: [String: Double] = [:] // Tracks who has paid what amount
    var settled: Bool = false
    var settledAt: Timestamp?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Expense, rhs: Expense) -> Bool {
        return lhs.id == rhs.id
    }
    
    // Custom coding keys to support optional fields
    enum CodingKeys: String, CodingKey {
        case id, amount, description, groupId, createdBy, createdAt, splitType, splits, customSplitPercentages, payments, settled, settledAt
    }
    
    // Custom decoder init to handle missing fields
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        amount = try container.decode(Double.self, forKey: .amount)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        groupId = try container.decode(String.self, forKey: .groupId)
        createdBy = try container.decode(String.self, forKey: .createdBy)
        createdAt = try container.decode(Timestamp.self, forKey: .createdAt)
        
        // Handle split type - default to .equal if missing
        if let splitTypeString = try container.decodeIfPresent(String.self, forKey: .splitType) {
            splitType = SplitType(rawValue: splitTypeString) ?? .equal
        } else {
            splitType = .equal
        }
        
        // Handle splits with default empty dictionary
        splits = try container.decodeIfPresent([String: Double].self, forKey: .splits) ?? [:]
        
        // Handle custom split percentages (optional)
        customSplitPercentages = try container.decodeIfPresent([String: Double].self, forKey: .customSplitPercentages)
        
        // Handle payments with default empty dictionary
        payments = try container.decodeIfPresent([String: Double].self, forKey: .payments) ?? [:]
        
        // Handle optional "settled" field with default value
        settled = try container.decodeIfPresent(Bool.self, forKey: .settled) ?? false
        settledAt = try container.decodeIfPresent(Timestamp.self, forKey: .settledAt)
    }
    
    // Regular init for creating expenses in code
    init(id: String, amount: Double, description: String? = nil, groupId: String, 
         createdBy: String, createdAt: Timestamp, splitType: SplitType = .equal,
         splits: [String: Double], customSplitPercentages: [String: Double]? = nil,
         payments: [String: Double] = [:], settled: Bool = false, settledAt: Timestamp? = nil) {
        self.id = id
        self.amount = amount
        self.description = description
        self.groupId = groupId
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.splitType = splitType
        self.splits = splits
        self.customSplitPercentages = customSplitPercentages
        self.payments = payments
        self.settled = settled
        self.settledAt = settledAt
    }
    
    // MARK: - Custom Split Helpers
    
    /// Calculates splits based on percentage allocations for custom split type
    /// - Parameters:
    ///   - percentages: Dictionary mapping user IDs to percentage values (0-100)
    ///   - amount: Total expense amount
    /// - Returns: Dictionary mapping user IDs to dollar amounts
    static func calculateSplitsFromPercentages(_ percentages: [String: Double], amount: Double) -> [String: Double] {
        var splits: [String: Double] = [:]
        for (userId, percentage) in percentages {
            splits[userId] = amount * (percentage / 100.0)
        }
        return splits
    }
    
    /// Validates that custom split percentages sum to 100%
    /// - Parameter percentages: Dictionary mapping user IDs to percentage values
    /// - Returns: True if percentages sum to 100% (within 0.01% tolerance), false otherwise
    static func validatePercentages(_ percentages: [String: Double]) -> Bool {
        let total = percentages.values.reduce(0, +)
        return abs(total - 100.0) < 0.01
    }
    
    /// Applies custom split percentages to this expense and updates the splits
    mutating func applyCustomSplitPercentages() {
        guard splitType == .custom,
              let percentages = customSplitPercentages,
              Self.validatePercentages(percentages) else {
            return
        }
        
        splits = Self.calculateSplitsFromPercentages(percentages, amount: amount)
    }
    
    // Export functionality
    
    /// Exports the expense as a CSV string
    /// - Parameter memberNames: A dictionary mapping member IDs to their display names for better readability
    /// - Returns: A string in CSV format representing the expense
    func toCSV(memberNames: [String: String] = [:]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        
        // CSV Header
        var csv = "Expense ID,Description,Amount,Created By,Created At,Split Type,Status"
        
        // Add split headers for each member
        let sortedMemberIds = splits.keys.sorted()
        for memberId in sortedMemberIds {
            let name = memberNames[memberId] ?? memberId
            csv += ",\(escapeCSV(name)) Share"
        }
        csv += "\n"
        
        // CSV Data row
        csv += escapeCSV(id) + ","
        csv += escapeCSV(description ?? "Expense") + ","
        csv += String(format: "%.2f", amount) + ","
        csv += escapeCSV(memberNames[createdBy] ?? createdBy) + ","
        csv += escapeCSV(dateFormatter.string(from: createdAt.dateValue())) + ","
        csv += escapeCSV(splitType.rawValue.capitalized) + ","
        csv += escapeCSV(settled ? "Settled" : "Unsettled")
        
        // Add split amounts for each member
        for memberId in sortedMemberIds {
            if let splitAmount = splits[memberId] {
                csv += ",\(String(format: "%.2f", splitAmount))"
            } else {
                csv += ",0.00"
            }
        }
        
        return csv
    }
    
    /// Escapes a string for CSV format (wraps in quotes if needed and escapes double quotes)
    private func escapeCSV(_ value: String) -> String {
        let needsEscaping = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsEscaping {
            // Double any quotes and wrap in quotes
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    /// Exports a collection of expenses as a CSV string
    /// - Parameters:
    ///   - expenses: The array of expenses to export
    ///   - memberNames: A dictionary mapping member IDs to their display names
    /// - Returns: A string in CSV format representing all expenses
    static func expensesToCSV(_ expenses: [Expense], memberNames: [String: String] = [:]) -> String {
        guard !expenses.isEmpty else { return "" }
        
        // Get header from the first expense
        var csv = expenses[0].toCSV(memberNames: memberNames)
        
        // For remaining expenses, only include the data (not the header)
        for i in 1..<expenses.count {
            let expenseCsv = expenses[i].toCSV(memberNames: memberNames)
            let lines = expenseCsv.components(separatedBy: "\n")
            if lines.count > 1 {
                csv += "\n" + lines[1] // Add just the data line, not the header
            }
        }
        
        return csv
    }
    
    // MARK: - Import Functionality
    
    /// A struct to hold the result of a CSV import operation
    struct ImportResult {
        let validExpenses: [Expense]
        let invalidRowIndices: [Int]
        let errorMessages: [String]
        
        var isSuccessful: Bool {
            return !validExpenses.isEmpty
        }
        
        var summary: String {
            let validCount = validExpenses.count
            let invalidCount = invalidRowIndices.count
            
            var result = "Successfully parsed \(validCount) expense(s)"
            if invalidCount > 0 {
                result += " with \(invalidCount) invalid row(s)"
            }
            return result
        }
    }
    
    /// Imports expenses from a CSV string
    /// - Parameters:
    ///   - csvString: The CSV string to parse
    ///   - groupId: The group ID to associate with imported expenses
    ///   - creatorId: The user ID of the person importing the expenses
    ///   - memberIds: The list of member IDs in the group (for splits)
    ///   - maxImports: Maximum number of expenses to import (default: 100)
    /// - Returns: An ImportResult containing parsed expenses and any error information
    static func importFromCSV(csvString: String, groupId: String, creatorId: String, memberIds: [String], maxImports: Int = 100) -> ImportResult {
        var validExpenses: [Expense] = []
        var invalidRowIndices: [Int] = []
        var errorMessages: [String] = []
        
        // Split into lines and get header
        let lines = csvString.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard lines.count > 1 else {
            return ImportResult(
                validExpenses: [],
                invalidRowIndices: [0],
                errorMessages: ["CSV file must contain at least a header row and one data row"]
            )
        }
        
        // Parse header to find column indices
        let headerRow = parseCSVRow(lines[0])
        var descriptionIndex: Int?
        var amountIndex: Int?
        var dateIndex: Int?
        var statusIndex: Int?
        
        for (index, header) in headerRow.enumerated() {
            let normalizedHeader = header.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            
            switch normalizedHeader {
                case "description":
                    descriptionIndex = index
                case "amount":
                    amountIndex = index
                case "date", "created at":
                    dateIndex = index
                case "status":
                    statusIndex = index
                default:
                    // Ignore unrecognized columns
                    continue
            }
        }
        
        // Check for required columns
        guard let amountIdx = amountIndex else {
            return ImportResult(
                validExpenses: [],
                invalidRowIndices: [0],
                errorMessages: ["CSV must contain an 'Amount' column"]
            )
        }
        
        // Process data rows (enforce limit)
        let dataRows = Array(lines.dropFirst())
        let rowLimit = min(dataRows.count, maxImports)
        
        for (i, line) in dataRows.prefix(rowLimit).enumerated() {
            let rowIndex = i + 1 // Account for header (for error reporting)
            let values = parseCSVRow(line)
            
            // Skip row if it doesn't have enough columns
            if values.count <= amountIdx {
                invalidRowIndices.append(rowIndex)
                errorMessages.append("Row \(rowIndex): Not enough columns")
                continue
            }
            
            // Parse amount (required)
            guard let amount = Double(values[amountIdx].replacingOccurrences(of: ",", with: "")) else {
                invalidRowIndices.append(rowIndex)
                errorMessages.append("Row \(rowIndex): Invalid amount value '\(values[amountIdx])'")
                continue
            }
            
            // Validate amount is positive
            guard amount > 0 else {
                invalidRowIndices.append(rowIndex)
                errorMessages.append("Row \(rowIndex): Amount must be greater than zero")
                continue
            }
            
            // Get description (optional with default)
            let description = descriptionIndex.flatMap { idx -> String? in
                if idx < values.count {
                    let desc = values[idx].trimmingCharacters(in: .whitespacesAndNewlines)
                    return desc.isEmpty ? nil : desc
                }
                return nil
            } ?? "Imported Expense"
            
            // Parse date (optional with default)
            let createdAt: Timestamp
            if let dateIdx = dateIndex, dateIdx < values.count {
                let dateString = values[dateIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                if let date = parseDate(dateString) {
                    createdAt = Timestamp(date: date)
                } else {
                    createdAt = Timestamp()
                }
            } else {
                createdAt = Timestamp() // Default to current date
            }
            
            // Parse status (optional with default)
            let settled: Bool
            if let statusIdx = statusIndex, statusIdx < values.count {
                let statusString = values[statusIdx].lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                settled = statusString == "settled" || statusString == "true" || statusString == "yes"
            } else {
                settled = false // Default to unsettled
            }
            
            // Create default equal splits for all members
            var splits: [String: Double] = [:]
            let equalShare = amount / Double(memberIds.count)
            for memberId in memberIds {
                splits[memberId] = equalShare
            }
            
            // Assume the importer (creator) has paid the full amount
            var payments: [String: Double] = [:]
            payments[creatorId] = amount
            
            // Create expense
            let expense = Expense(
                id: UUID().uuidString, // Generate a new ID
                amount: amount,
                description: description,
                groupId: groupId,
                createdBy: creatorId,
                createdAt: createdAt,
                splitType: .equal, // Default to equal split
                splits: splits,
                payments: payments,
                settled: settled,
                settledAt: settled ? Timestamp() : nil
            )
            
            validExpenses.append(expense)
        }
        
        // Check if we exceeded the import limit
        if dataRows.count > maxImports {
            errorMessages.append("Import limit of \(maxImports) expenses reached. \(dataRows.count - maxImports) expenses were not imported.")
        }
        
        return ImportResult(
            validExpenses: validExpenses,
            invalidRowIndices: invalidRowIndices,
            errorMessages: errorMessages
        )
    }
    
    /// Parses a CSV row into individual values, handling quoted values
    private static func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var currentValue = ""
        var inQuotes = false
        
        for char in row {
            switch char {
                case "\"":
                    inQuotes.toggle()
                case ",":
                    if inQuotes {
                        currentValue.append(char)
                    } else {
                        result.append(currentValue)
                        currentValue = ""
                    }
                default:
                    currentValue.append(char)
            }
        }
        
        // Add the last value
        result.append(currentValue)
        
        return result
    }
    
    /// Attempts to parse a date string in various common formats
    private static func parseDate(_ dateString: String) -> Date? {
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yyyy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "MM/dd/yy"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                formatter.timeStyle = .short
                return formatter
            }()
        ]
        
        for formatter in dateFormatters {
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

