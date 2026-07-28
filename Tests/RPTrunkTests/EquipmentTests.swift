@testable import RPTrunk
import XCTest

enum TestEquipment {
    static func item(
        _ code: String,
        slot: RPEquipmentSlotCode?,
        damage: Int
    ) -> RPActiveItem<TestRPSpace> {
        var active = RPActiveItem<TestRPSpace>(item: RPItem(
            code: code,
            fragments: [RPFragment(stats: .init(dict: [\.damage: damage]))],
            equipmentSlotCode: slot
        ))
        active.id = code
        return active
    }

    static var sword: RPActiveItem<TestRPSpace> { item("sword", slot: "weapon", damage: 10) }
    static var helmet: RPActiveItem<TestRPSpace> { item("helmet", slot: "head", damage: 5) }
    static var potion: RPActiveItem<TestRPSpace> { item("potion", slot: nil, damage: 99) }
}

final class EquipmentTests: XCTestCase {
    var body: RPBody<TestRPSpace>!

    override func setUp() {
        body = RPBody(equipmentSlotCapacities: ["weapon": 1, "trinket": 2])
    }

    func test_undeclared_slot_is_unlimited() {
        XCTAssertNil(body.capacity(ofSlot: "head"))
        for index in 0 ..< 5 {
            XCTAssertTrue(body.equip(TestEquipment.item("hat-\(index)", slot: "head", damage: 1)))
        }
        XCTAssertEqual(body.items(inSlot: "head").count, 5)
    }

    func test_declared_capacity_is_enforced() {
        XCTAssertTrue(body.equip(TestEquipment.sword))
        XCTAssertFalse(body.hasRoom(inSlot: "weapon"))
        XCTAssertFalse(body.equip(TestEquipment.item("axe", slot: "weapon", damage: 12)))
        XCTAssertEqual(body.items(inSlot: "weapon").map(\.code), ["sword"])
    }

    func test_slot_can_declare_more_than_one_opening() {
        XCTAssertTrue(body.equip(TestEquipment.item("ring", slot: "trinket", damage: 1)))
        XCTAssertTrue(body.equip(TestEquipment.item("amulet", slot: "trinket", damage: 2)))
        XCTAssertFalse(body.equip(TestEquipment.item("charm", slot: "trinket", damage: 3)))
        XCTAssertEqual(body.items(inSlot: "trinket").count, 2)
    }

    func test_item_without_slot_code_is_not_equippable() {
        XCTAssertFalse(body.canEquip(TestEquipment.potion))
        XCTAssertFalse(body.equip(TestEquipment.potion))
        XCTAssertTrue(body.wornItems.isEmpty)
    }

    func test_unequip_frees_the_slot_and_returns_the_item() {
        body.equip(TestEquipment.sword)
        let removed = body.unequip(itemId: "sword")
        XCTAssertEqual(removed?.code, "sword")
        XCTAssertTrue(body.hasRoom(inSlot: "weapon"))
        XCTAssertNil(body.unequip(itemId: "sword"))
        XCTAssertTrue(body.equipmentSlots.isEmpty)
    }

    func test_worn_items_spans_every_slot_in_a_stable_order() {
        body.equip(TestEquipment.helmet)
        body.equip(TestEquipment.sword)
        body.equip(TestEquipment.item("ring", slot: "trinket", damage: 1))

        XCTAssertEqual(body.wornItems.map(\.code), ["helmet", "ring", "sword"])
        for _ in 0 ..< 20 {
            XCTAssertEqual(body.wornItems.map(\.code), ["helmet", "ring", "sword"])
        }
    }

    func test_unequip_all_empties_the_body() {
        body.equip(TestEquipment.sword)
        body.equip(TestEquipment.helmet)
        XCTAssertEqual(Set(body.unequipAll().map(\.code)), ["sword", "helmet"])
        XCTAssertTrue(body.wornItems.isEmpty)
    }

    func test_code_encodes_as_a_bare_string_not_a_wrapper_object() throws {
        let encoded = try JSONEncoder().encode(["slot": RPEquipmentSlotCode("trinket")])
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #"{"slot":"trinket"}"#)

        let decoded = try JSONDecoder().decode(
            [String: RPEquipmentSlotCode].self,
            from: Data(#"{"slot":"trinket"}"#.utf8)
        )
        XCTAssertEqual(decoded["slot"], "trinket")
    }

    func test_code_keyed_dictionary_encodes_as_a_json_object() throws {
        let capacities: [RPEquipmentSlotCode: Int] = ["trinket": 2]
        let encoded = try JSONEncoder().encode(capacities)
        XCTAssertEqual(String(decoding: encoded, as: UTF8.self), #"{"trinket":2}"#)

        let decoded = try JSONDecoder().decode(
            [RPEquipmentSlotCode: Int].self,
            from: Data(#"{"trinket":2,"weapon":1}"#.utf8)
        )
        XCTAssertEqual(decoded[RPEquipmentSlotCode("trinket")], 2)
        XCTAssertEqual(decoded[RPEquipmentSlotCode("weapon")], 1)
    }

    func test_body_survives_a_codable_round_trip() throws {
        body.equip(TestEquipment.sword)
        body.equip(TestEquipment.helmet)
        let data = try JSONEncoder().encode(body)
        let decoded = try JSONDecoder().decode(RPBody<TestRPSpace>.self, from: data)
        XCTAssertEqual(decoded, body)
        XCTAssertEqual(decoded.capacity(ofSlot: "weapon"), 1)
        XCTAssertEqual(decoded.wornItems.map(\.code), ["helmet", "sword"])
    }
}

final class EquipmentSpaceTests: XCTestCase {
    var rpSpace: TestRPSpace!

    override func setUp() {
        rpSpace = TestRPSpace()
        var entity = RPEntity<TestRPSpace>(["hp": 30])
        entity.id = "wearer"
        entity.body.equipmentSlotCapacities = ["weapon": 1]
        rpSpace.addEntity(entity)
    }

    func test_equipping_moves_the_item_from_inventory_to_the_body() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        XCTAssertTrue(rpSpace.equipItem(id: "sword", on: "wearer"))

        let wearer = rpSpace.entityById("wearer")!
        XCTAssertTrue(wearer.inventory.isEmpty)
        XCTAssertEqual(wearer.body.wornItems.map(\.code), ["sword"])
        XCTAssertEqual(wearer.getTotalStats().damage, 10)
    }

    func test_equipping_fails_when_the_slot_is_full_and_leaves_the_item_carried() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.receiveItem(TestEquipment.item("axe", slot: "weapon", damage: 12), to: "wearer")
        XCTAssertTrue(rpSpace.equipItem(id: "sword", on: "wearer"))
        XCTAssertFalse(rpSpace.equipItem(id: "axe", on: "wearer"))

        let wearer = rpSpace.entityById("wearer")!
        XCTAssertEqual(wearer.inventory.map(\.code), ["axe"])
        XCTAssertEqual(wearer.body.wornItems.map(\.code), ["sword"])
    }

    func test_unequipping_returns_the_item_to_inventory() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        XCTAssertTrue(rpSpace.unequipItem(id: "sword", on: "wearer"))

        let wearer = rpSpace.entityById("wearer")!
        XCTAssertEqual(wearer.inventory.map(\.code), ["sword"])
        XCTAssertTrue(wearer.body.wornItems.isEmpty)
        XCTAssertEqual(wearer.getTotalStats().damage, 0)
    }

    func test_transfer_takes_worn_items_off_the_body() {
        var looter = RPEntity<TestRPSpace>(["hp": 30])
        looter.id = "looter"
        rpSpace.addEntity(looter)

        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        rpSpace.transferItem(id: "sword", from: "wearer", to: "looter")

        XCTAssertTrue(rpSpace.entityById("wearer")!.body.wornItems.isEmpty)
        XCTAssertEqual(rpSpace.entityById("looter")!.inventory.map(\.code), ["sword"])
    }

    func test_transfer_all_strips_both_inventory_and_body() {
        var looter = RPEntity<TestRPSpace>(["hp": 30])
        looter.id = "looter"
        rpSpace.addEntity(looter)

        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.receiveItem(TestEquipment.potion, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        rpSpace.transferAllItems(from: "wearer", to: "looter")

        let wearer = rpSpace.entityById("wearer")!
        XCTAssertTrue(wearer.inventory.isEmpty)
        XCTAssertTrue(wearer.body.wornItems.isEmpty)
        XCTAssertEqual(Set(rpSpace.entityById("looter")!.inventory.map(\.code)), ["sword", "potion"])
    }
}
