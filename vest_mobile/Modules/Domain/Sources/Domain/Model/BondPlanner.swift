import Foundation

public struct BondPlannerSettings: Equatable, Sendable, Codable {
    public var targetMonthlyNominal: Double
    public var horizonYears: Int
    public var investmentBudget: Double
    public var includeFamilyBonds: Bool
    public var customInflationRatePct: Double?
    public var customNbpRatePct: Double?

    public init(
        targetMonthlyNominal: Double = 3000.0,
        horizonYears: Int = 5,
        investmentBudget: Double = 10000.0,
        includeFamilyBonds: Bool = false,
        customInflationRatePct: Double? = nil,
        customNbpRatePct: Double? = nil
    ) {
        self.targetMonthlyNominal = targetMonthlyNominal
        self.horizonYears = horizonYears
        self.investmentBudget = investmentBudget
        self.includeFamilyBonds = includeFamilyBonds
        self.customInflationRatePct = customInflationRatePct
        self.customNbpRatePct = customNbpRatePct
    }
}

public struct BondOfferSeries: Identifiable, Equatable, Sendable, Codable {
    public var id: String { code }
    public let code: String
    public let type: String
    public let name: String
    public let durationYears: Int
    public let maturityMonth: Int
    public let maturityYear: Int
    public let maturityLabel: String
    public let firstYearRatePct: Double
    public let marginPct: Double
    public let earlyRedemptionFeePLN: Double
    public let isFamilyBond: Bool
    public let indexation: String
    public let payoutType: String

    public init(
        code: String,
        type: String,
        name: String,
        durationYears: Int,
        maturityMonth: Int,
        maturityYear: Int,
        maturityLabel: String,
        firstYearRatePct: Double,
        marginPct: Double,
        earlyRedemptionFeePLN: Double,
        isFamilyBond: Bool,
        indexation: String,
        payoutType: String
    ) {
        self.code = code
        self.type = type
        self.name = name
        self.durationYears = durationYears
        self.maturityMonth = maturityMonth
        self.maturityYear = maturityYear
        self.maturityLabel = maturityLabel
        self.firstYearRatePct = firstYearRatePct
        self.marginPct = marginPct
        self.earlyRedemptionFeePLN = earlyRedemptionFeePLN
        self.isFamilyBond = isFamilyBond
        self.indexation = indexation
        self.payoutType = payoutType
    }
}

public struct BondMarketConditions: Equatable, Sendable, Codable {
    public let referenceDate: String
    public let issueMonth: Int
    public let issueYear: Int
    public let issueMonthLabel: String
    public let liveInflationRatePct: Double
    public let liveNbpReferenceRatePct: Double
    public let effectiveInflationRatePct: Double
    public let effectiveNbpReferenceRatePct: Double
    public let sourceUrl: String
    public let availableSeries: [BondOfferSeries]

    public init(
        referenceDate: String,
        issueMonth: Int,
        issueYear: Int,
        issueMonthLabel: String,
        liveInflationRatePct: Double,
        liveNbpReferenceRatePct: Double,
        effectiveInflationRatePct: Double,
        effectiveNbpReferenceRatePct: Double,
        sourceUrl: String,
        availableSeries: [BondOfferSeries]
    ) {
        self.referenceDate = referenceDate
        self.issueMonth = issueMonth
        self.issueYear = issueYear
        self.issueMonthLabel = issueMonthLabel
        self.liveInflationRatePct = liveInflationRatePct
        self.liveNbpReferenceRatePct = liveNbpReferenceRatePct
        self.effectiveInflationRatePct = effectiveInflationRatePct
        self.effectiveNbpReferenceRatePct = effectiveNbpReferenceRatePct
        self.sourceUrl = sourceUrl
        self.availableSeries = availableSeries
    }
}

public struct BondComparisonOption: Identifiable, Equatable, Sendable, Codable {
    public var id: String { "\(bondCode)_\(holdingYears)" }
    public let bondCode: String
    public let bondType: String
    public let nativeDurationYears: Int
    public let holdingYears: Int
    public let isEarlyRedemption: Bool
    public let grossInterestPerBondPLN: Double
    public let earlyRedemptionFeePerBondPLN: Double
    public let taxPerBondPLN: Double
    public let netProfitPerBondPLN: Double
    public let netPayoutPerBondPLN: Double
    public let effectiveAnnualRatePct: Double

    public init(
        bondCode: String,
        bondType: String,
        nativeDurationYears: Int,
        holdingYears: Int,
        isEarlyRedemption: Bool,
        grossInterestPerBondPLN: Double,
        earlyRedemptionFeePerBondPLN: Double,
        taxPerBondPLN: Double,
        netProfitPerBondPLN: Double,
        netPayoutPerBondPLN: Double,
        effectiveAnnualRatePct: Double
    ) {
        self.bondCode = bondCode
        self.bondType = bondType
        self.nativeDurationYears = nativeDurationYears
        self.holdingYears = holdingYears
        self.isEarlyRedemption = isEarlyRedemption
        self.grossInterestPerBondPLN = grossInterestPerBondPLN
        self.earlyRedemptionFeePerBondPLN = earlyRedemptionFeePerBondPLN
        self.taxPerBondPLN = taxPerBondPLN
        self.netProfitPerBondPLN = netProfitPerBondPLN
        self.netPayoutPerBondPLN = netPayoutPerBondPLN
        self.effectiveAnnualRatePct = effectiveAnnualRatePct
    }
}

public struct YearlyContinuitySlot: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let year: Int
    public let month: Int
    public let label: String
    public let holdingYears: Int
    public let targetNominalPLN: Double
    public let existingNominalPLN: Double
    public let existingActualPLN: Double
    public let shortfallNominalPLN: Double
    public let allocatedNewNominalPLN: Double
    public let allocatedUnits: Int
    public let unfundedGapNominalPLN: Double
    public let recommendedBondCode: String?
    public let recommendedBondType: String?
    public let isEarlyRedemption: Bool
    public let earlyRedemptionTargetLabel: String?
    public let projectedNetProfitPLN: Double
    public let projectedTotalPayoutPLN: Double
    public let effectiveAnnualRatePct: Double
    public let heldBonds: [String]
    public let alternatives: [BondComparisonOption]

    public init(
        id: String,
        year: Int,
        month: Int,
        label: String,
        holdingYears: Int,
        targetNominalPLN: Double,
        existingNominalPLN: Double,
        existingActualPLN: Double,
        shortfallNominalPLN: Double,
        allocatedNewNominalPLN: Double,
        allocatedUnits: Int,
        unfundedGapNominalPLN: Double,
        recommendedBondCode: String?,
        recommendedBondType: String?,
        isEarlyRedemption: Bool,
        earlyRedemptionTargetLabel: String?,
        projectedNetProfitPLN: Double,
        projectedTotalPayoutPLN: Double,
        effectiveAnnualRatePct: Double,
        heldBonds: [String],
        alternatives: [BondComparisonOption]
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.label = label
        self.holdingYears = holdingYears
        self.targetNominalPLN = targetNominalPLN
        self.existingNominalPLN = existingNominalPLN
        self.existingActualPLN = existingActualPLN
        self.shortfallNominalPLN = shortfallNominalPLN
        self.allocatedNewNominalPLN = allocatedNewNominalPLN
        self.allocatedUnits = allocatedUnits
        self.unfundedGapNominalPLN = unfundedGapNominalPLN
        self.recommendedBondCode = recommendedBondCode
        self.recommendedBondType = recommendedBondType
        self.isEarlyRedemption = isEarlyRedemption
        self.earlyRedemptionTargetLabel = earlyRedemptionTargetLabel
        self.projectedNetProfitPLN = projectedNetProfitPLN
        self.projectedTotalPayoutPLN = projectedTotalPayoutPLN
        self.effectiveAnnualRatePct = effectiveAnnualRatePct
        self.heldBonds = heldBonds
        self.alternatives = alternatives
    }
}

public struct PurchaseAllocationItem: Identifiable, Equatable, Sendable, Codable {
    public var id: String { "\(targetLabel)_\(isSurplus ? "surplus" : "cont")" }
    public let targetLabel: String
    public let targetYear: Int
    public let targetMonth: Int
    public let holdingYears: Int
    public let units: Int
    public let nominalPLN: Double
    public let isEarlyRedemption: Bool
    public let isSurplus: Bool
    public let projectedNetProfitPLN: Double

    public init(
        targetLabel: String,
        targetYear: Int,
        targetMonth: Int,
        holdingYears: Int,
        units: Int,
        nominalPLN: Double,
        isEarlyRedemption: Bool,
        isSurplus: Bool,
        projectedNetProfitPLN: Double
    ) {
        self.targetLabel = targetLabel
        self.targetYear = targetYear
        self.targetMonth = targetMonth
        self.holdingYears = holdingYears
        self.units = units
        self.nominalPLN = nominalPLN
        self.isEarlyRedemption = isEarlyRedemption
        self.isSurplus = isSurplus
        self.projectedNetProfitPLN = projectedNetProfitPLN
    }
}

public struct BondPurchaseRecommendation: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let bondCode: String
    public let bondType: String
    public let bondName: String
    public let nativeMaturityLabel: String
    public let totalUnits: Int
    public let totalNominalPLN: Double
    public let requiredContinuityNominalPLN: Double
    public let surplusNominalPLN: Double
    public let projectedTotalNetProfitPLN: Double
    public let effectiveAnnualRatePct: Double
    public let firstYearRatePct: Double
    public let marginPct: Double
    public let earlyRedemptionFeePLN: Double
    public let allocations: [PurchaseAllocationItem]

    public init(
        id: String,
        bondCode: String,
        bondType: String,
        bondName: String,
        nativeMaturityLabel: String,
        totalUnits: Int,
        totalNominalPLN: Double,
        requiredContinuityNominalPLN: Double,
        surplusNominalPLN: Double,
        projectedTotalNetProfitPLN: Double,
        effectiveAnnualRatePct: Double,
        firstYearRatePct: Double,
        marginPct: Double,
        earlyRedemptionFeePLN: Double,
        allocations: [PurchaseAllocationItem]
    ) {
        self.id = id
        self.bondCode = bondCode
        self.bondType = bondType
        self.bondName = bondName
        self.nativeMaturityLabel = nativeMaturityLabel
        self.totalUnits = totalUnits
        self.totalNominalPLN = totalNominalPLN
        self.requiredContinuityNominalPLN = requiredContinuityNominalPLN
        self.surplusNominalPLN = surplusNominalPLN
        self.projectedTotalNetProfitPLN = projectedTotalNetProfitPLN
        self.effectiveAnnualRatePct = effectiveAnnualRatePct
        self.firstYearRatePct = firstYearRatePct
        self.marginPct = marginPct
        self.earlyRedemptionFeePLN = earlyRedemptionFeePLN
        self.allocations = allocations
    }
}

public struct EarlyRedemptionRecommendation: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let targetYear: Int
    public let targetMonth: Int
    public let targetLabel: String
    public let shortfallNominalPLN: Double
    public let sourceBondCode: String
    public let sourceBondType: String
    public let sourceMaturityLabel: String
    public let recommendedRedeemUnits: Int
    public let recommendedRedeemNominalPLN: Double
    public let estimatedFeePLN: Double
    public let isAnniversaryMonthMatch: Bool
    public let reason: String

    public init(
        id: String,
        targetYear: Int,
        targetMonth: Int,
        targetLabel: String,
        shortfallNominalPLN: Double,
        sourceBondCode: String,
        sourceBondType: String,
        sourceMaturityLabel: String,
        recommendedRedeemUnits: Int,
        recommendedRedeemNominalPLN: Double,
        estimatedFeePLN: Double,
        isAnniversaryMonthMatch: Bool,
        reason: String
    ) {
        self.id = id
        self.targetYear = targetYear
        self.targetMonth = targetMonth
        self.targetLabel = targetLabel
        self.shortfallNominalPLN = shortfallNominalPLN
        self.sourceBondCode = sourceBondCode
        self.sourceBondType = sourceBondType
        self.sourceMaturityLabel = sourceMaturityLabel
        self.recommendedRedeemUnits = recommendedRedeemUnits
        self.recommendedRedeemNominalPLN = recommendedRedeemNominalPLN
        self.estimatedFeePLN = estimatedFeePLN
        self.isAnniversaryMonthMatch = isAnniversaryMonthMatch
        self.reason = reason
    }
}

public struct HeldBondSlice: Identifiable, Equatable, Sendable, Codable {
    public var id: String { code }
    public let code: String
    public let nominalPLN: Double
    public let actualPLN: Double

    public init(code: String, nominalPLN: Double, actualPLN: Double) {
        self.code = code
        self.nominalPLN = nominalPLN
        self.actualPLN = actualPLN
    }
}

public struct MonthlyMaturityCell: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let year: Int
    public let month: Int
    public let monthShortLabel: String
    public let label: String
    public let targetNominalPLN: Double
    public let existingNominalPLN: Double
    public let proposedNominalPLN: Double
    public let shortfallNominalPLN: Double
    public let surplusNominalPLN: Double
    public let coveragePct: Double
    public let isCurrentIssueMonth: Bool
    public let heldBonds: [HeldBondSlice]

    public init(
        id: String,
        year: Int,
        month: Int,
        monthShortLabel: String,
        label: String,
        targetNominalPLN: Double,
        existingNominalPLN: Double,
        proposedNominalPLN: Double,
        shortfallNominalPLN: Double,
        surplusNominalPLN: Double,
        coveragePct: Double,
        isCurrentIssueMonth: Bool,
        heldBonds: [HeldBondSlice]
    ) {
        self.id = id
        self.year = year
        self.month = month
        self.monthShortLabel = monthShortLabel
        self.label = label
        self.targetNominalPLN = targetNominalPLN
        self.existingNominalPLN = existingNominalPLN
        self.proposedNominalPLN = proposedNominalPLN
        self.shortfallNominalPLN = shortfallNominalPLN
        self.surplusNominalPLN = surplusNominalPLN
        self.coveragePct = coveragePct
        self.isCurrentIssueMonth = isCurrentIssueMonth
        self.heldBonds = heldBonds
    }
}

public struct YearlyMaturityRow: Identifiable, Equatable, Sendable, Codable {
    public let id: String
    public let year: Int
    public let totalExistingNominalPLN: Double
    public let totalProposedNominalPLN: Double
    public let totalTargetNominalPLN: Double
    public let months: [MonthlyMaturityCell]

    public init(
        id: String,
        year: Int,
        totalExistingNominalPLN: Double,
        totalProposedNominalPLN: Double,
        totalTargetNominalPLN: Double,
        months: [MonthlyMaturityCell]
    ) {
        self.id = id
        self.year = year
        self.totalExistingNominalPLN = totalExistingNominalPLN
        self.totalProposedNominalPLN = totalProposedNominalPLN
        self.totalTargetNominalPLN = totalTargetNominalPLN
        self.months = months
    }
}

public struct BondPlannerSummary: Equatable, Sendable, Codable {
    public let totalHeldBondsNominalPLN: Double
    public let totalHeldBondsActualPLN: Double
    public let currentMonthTargetSeriesCount: Int
    public let currentMonthCoveredYearsCount: Int
    public let totalRequiredForContinuityPLN: Double
    public let budgetAllocatedToContinuityPLN: Double
    public let budgetAllocatedToSurplusPLN: Double
    public let unfundedContinuityGapPLN: Double
    public let projectedTotalNetProfitFromBudgetPLN: Double

    public init(
        totalHeldBondsNominalPLN: Double,
        totalHeldBondsActualPLN: Double,
        currentMonthTargetSeriesCount: Int,
        currentMonthCoveredYearsCount: Int,
        totalRequiredForContinuityPLN: Double,
        budgetAllocatedToContinuityPLN: Double,
        budgetAllocatedToSurplusPLN: Double,
        unfundedContinuityGapPLN: Double,
        projectedTotalNetProfitFromBudgetPLN: Double
    ) {
        self.totalHeldBondsNominalPLN = totalHeldBondsNominalPLN
        self.totalHeldBondsActualPLN = totalHeldBondsActualPLN
        self.currentMonthTargetSeriesCount = currentMonthTargetSeriesCount
        self.currentMonthCoveredYearsCount = currentMonthCoveredYearsCount
        self.totalRequiredForContinuityPLN = totalRequiredForContinuityPLN
        self.budgetAllocatedToContinuityPLN = budgetAllocatedToContinuityPLN
        self.budgetAllocatedToSurplusPLN = budgetAllocatedToSurplusPLN
        self.unfundedContinuityGapPLN = unfundedContinuityGapPLN
        self.projectedTotalNetProfitFromBudgetPLN = projectedTotalNetProfitFromBudgetPLN
    }
}

public struct BondPlannerData: Equatable, Sendable, Codable {
    public let settings: BondPlannerSettings
    public let market: BondMarketConditions
    public let summary: BondPlannerSummary
    public let yearlyContinuitySlots: [YearlyContinuitySlot]
    public let purchaseRecommendations: [BondPurchaseRecommendation]
    public let earlyRedemptionRecommendations: [EarlyRedemptionRecommendation]
    public let maturityCalendar: [YearlyMaturityRow]

    public init(
        settings: BondPlannerSettings,
        market: BondMarketConditions,
        summary: BondPlannerSummary,
        yearlyContinuitySlots: [YearlyContinuitySlot],
        purchaseRecommendations: [BondPurchaseRecommendation],
        earlyRedemptionRecommendations: [EarlyRedemptionRecommendation],
        maturityCalendar: [YearlyMaturityRow]
    ) {
        self.settings = settings
        self.market = market
        self.summary = summary
        self.yearlyContinuitySlots = yearlyContinuitySlots
        self.purchaseRecommendations = purchaseRecommendations
        self.earlyRedemptionRecommendations = earlyRedemptionRecommendations
        self.maturityCalendar = maturityCalendar
    }
}

public struct BondPlannerQuery: Equatable, Sendable {
    public var targetMonthly: Double?
    public var horizonYears: Int?
    public var budget: Double?
    public var includeFamilyBonds: Bool?
    public var inflationRate: Double?
    public var nbpRate: Double?
    public var referenceMonth: Int?

    public init(
        targetMonthly: Double? = nil,
        horizonYears: Int? = nil,
        budget: Double? = nil,
        includeFamilyBonds: Bool? = nil,
        inflationRate: Double? = nil,
        nbpRate: Double? = nil,
        referenceMonth: Int? = nil
    ) {
        self.targetMonthly = targetMonthly
        self.horizonYears = horizonYears
        self.budget = budget
        self.includeFamilyBonds = includeFamilyBonds
        self.inflationRate = inflationRate
        self.nbpRate = nbpRate
        self.referenceMonth = referenceMonth
    }
}
