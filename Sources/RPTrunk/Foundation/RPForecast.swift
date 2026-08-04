public struct RPForecast<RP: RPSpace>: Equatable, Codable {
    public enum Origin: Equatable, Codable {
        case root
        case trigger(
            owner: RPBodyId,
            source: RPTriggerSource,
            code: RPReferenceCode,
            chancePercent: RPValue
        )
    }

    public struct ForecastedEvent: Equatable, Codable {
        public let event: RPEvent<RP>
        public let result: RPEventResult<RP>
        public let origin: Origin
        public let depth: Int

        /// `result` is already resolved, so replaying a forecasted event applies it rather
        /// than rolling again. `depth` keeps the shape the flat list loses.
        public init(
            event: RPEvent<RP>,
            result: RPEventResult<RP>,
            origin: Origin,
            depth: Int
        ) {
            self.event = event
            self.result = result
            self.origin = origin
            self.depth = depth
        }

        public var wasChanceGated: Bool {
            guard case let .trigger(_, _, _, chancePercent) = origin else { return false }
            return chancePercent < RPChance.certain
        }
    }

    public let forecastedEvents: [ForecastedEvent]
    public let wasTruncated: Bool

    public init(forecastedEvents: [ForecastedEvent], wasTruncated: Bool) {
        self.forecastedEvents = forecastedEvents
        self.wasTruncated = wasTruncated
    }

    public var root: ForecastedEvent { forecastedEvents[0] }
    public var reactions: ArraySlice<ForecastedEvent> { forecastedEvents.dropFirst() }
}
