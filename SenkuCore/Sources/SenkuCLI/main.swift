import Foundation
import SenkuCore

let usage = """
senku — Senku's nutrition core, on the command line

USAGE
  senku verify                 Run the built-in arithmetic checks
  senku demo                   Print a sample plan
  senku plan [options]         Print a plan for the given inputs

PLAN OPTIONS
  --sex male|female            (required)
  --age <years>                (required)
  --height <cm>                (required)
  --weight <kg>                (required)
  --bodyfat <percent>          Optional. Unlocks Katch-McArdle and lean-mass protein.
  --activity <level>           sedentary|light|moderate|active|athlete   (default: moderate)
  --goal <goal>                aggressiveCut|moderateCut|mildCut|maintain|
                               leanBulk|moderateBulk|aggressiveBulk      (default: maintain)

EXAMPLE
  senku plan --sex male --age 30 --height 180 --weight 80 --goal moderateCut
"""

struct CLIError: Error { let message: String }

func parseOptions(_ arguments: [String]) throws -> [String: String] {
    var options: [String: String] = [:]
    var index = 0
    while index < arguments.count {
        let token = arguments[index]
        guard token.hasPrefix("--") else {
            throw CLIError(message: "Unexpected argument '\(token)'.")
        }
        guard index + 1 < arguments.count else {
            throw CLIError(message: "Option '\(token)' needs a value.")
        }
        options[String(token.dropFirst(2)).lowercased()] = arguments[index + 1]
        index += 2
    }
    return options
}

func buildPlan(from options: [String: String]) throws -> NutritionPlan {
    func required(_ key: String) throws -> String {
        guard let value = options[key] else {
            throw CLIError(message: "Missing required option --\(key).")
        }
        return value
    }

    func number(_ key: String) throws -> Double {
        let raw = try required(key)
        guard let value = Double(raw) else {
            throw CLIError(message: "--\(key) expects a number, got '\(raw)'.")
        }
        return value
    }

    let sexRaw = try required("sex").lowercased()
    guard let sex = Sex(rawValue: sexRaw) else {
        throw CLIError(message: "--sex expects male or female, got '\(sexRaw)'.")
    }

    let ageValue = try number("age")
    guard ageValue == ageValue.rounded() else {
        throw CLIError(message: "--age expects a whole number of years.")
    }

    var bodyFat: Double?
    if let raw = options["bodyfat"] {
        guard let value = Double(raw) else {
            throw CLIError(message: "--bodyfat expects a number, got '\(raw)'.")
        }
        bodyFat = value
    }

    let activityRaw = options["activity"] ?? "moderate"
    guard let activity = ActivityLevel(rawValue: activityRaw) else {
        throw CLIError(message: "Unknown activity level '\(activityRaw)'.")
    }

    let goalRaw = options["goal"] ?? "maintain"
    guard let goal = Goal(rawValue: goalRaw) else {
        throw CLIError(message: "Unknown goal '\(goalRaw)'.")
    }

    let metrics = try BodyMetrics(
        sex: sex,
        age: Int(ageValue),
        heightCM: try number("height"),
        weightKG: try number("weight"),
        bodyFatPercentage: bodyFat
    )

    return NutritionPlan.make(for: metrics, activityLevel: activity, goal: goal)
}

let arguments = Array(CommandLine.arguments.dropFirst())
let command = arguments.first ?? "demo"

switch command {
case "verify":
    exit(runVerification())

case "demo":
    let metrics = try! BodyMetrics(
        sex: .male, age: 30, heightCM: 180, weightKG: 80, bodyFatPercentage: 18
    )
    print(render(NutritionPlan.make(for: metrics, activityLevel: .moderate, goal: .moderateCut)))

case "plan":
    do {
        print(render(try buildPlan(from: try parseOptions(Array(arguments.dropFirst())))))
    } catch let error as CLIError {
        FileHandle.standardError.write(Data("error: \(error.message)\n".utf8))
        exit(2)
    } catch let error as ValidationError {
        let message = error.errorDescription ?? "Invalid input."
        FileHandle.standardError.write(Data("error: \(message)\n".utf8))
        exit(2)
    }

case "--help", "-h", "help":
    print(usage)

default:
    FileHandle.standardError.write(Data("error: unknown command '\(command)'\n\n\(usage)\n".utf8))
    exit(2)
}
