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

    public struct Node: Equatable, Codable {
        public let event: RPEvent<RP>
        public let result: RPEventResult<RP>
        public let origin: Origin
        public let depth: Int

        /// `result` is the *resolved* outcome — the dice for this event were
        /// already rolled against the simulated copy — so replaying a node means
        /// applying this verbatim rather than resolving again. `depth` retains
        /// the tree shape that the flat node list otherwise flattens away.
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

        /// Whether luck decided this node existed. The chain past it is explored
        /// like any other, so a consumer weighing a move — an AI, say — can
        /// discount these branches without the forecast having refused to
        /// predict them.
        public var wasChanceGated: Bool {
            guard case let .trigger(_, _, _, chancePercent) = origin else { return false }
            return chancePercent < RPChance.certain
        }
    }

    public let nodes: [Node]
    public let wasTruncated: Bool

    /// `nodes` is flat and in play order — the event, then what it provoked,
    /// then what those provoked — so a consumer walks it with an index rather
    /// than recursing. `wasTruncated` reports that the walk hit
    /// `maximumForecastNodes` and stopped early, which is the only way a chain
    /// ends without exhausting itself.
    public init(nodes: [Node], wasTruncated: Bool) {
        self.nodes = nodes
        self.wasTruncated = wasTruncated
    }

    public var root: Node { nodes[0] }
    public var reactions: ArraySlice<Node> { nodes.dropFirst() }
}
