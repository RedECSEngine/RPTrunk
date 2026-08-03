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
    var equipment: RPEquipment<TestRPSpace>!

    override func setUp() {
        equipment = RPEquipment(equipmentSlotCapacities: ["weapon": 1, "trinket": 2])
    }

    func test_undeclared_slot_is_unlimited() {
        XCTAssertNil(equipment.capacity(ofSlot: "head"))
        for index in 0 ..< 5 {
            XCTAssertTrue(equipment.equip(TestEquipment.item("hat-\(index)", slot: "head", damage: 1)))
        }
        XCTAssertEqual(equipment.items(inSlot: "head").count, 5)
    }

    func test_declared_capacity_is_enforced() {
        XCTAssertTrue(equipment.equip(TestEquipment.sword))
        XCTAssertFalse(equipment.hasRoom(inSlot: "weapon"))
        XCTAssertFalse(equipment.equip(TestEquipment.item("axe", slot: "weapon", damage: 12)))
        XCTAssertEqual(equipment.items(inSlot: "weapon").map(\.code), ["sword"])
    }

    func test_slot_can_declare_more_than_one_opening() {
        XCTAssertTrue(equipment.equip(TestEquipment.item("ring", slot: "trinket", damage: 1)))
        XCTAssertTrue(equipment.equip(TestEquipment.item("amulet", slot: "trinket", damage: 2)))
        XCTAssertFalse(equipment.equip(TestEquipment.item("charm", slot: "trinket", damage: 3)))
        XCTAssertEqual(equipment.items(inSlot: "trinket").count, 2)
    }

    func test_item_without_slot_code_is_not_equippable() {
        XCTAssertFalse(equipment.canEquip(TestEquipment.potion))
        XCTAssertFalse(equipment.equip(TestEquipment.potion))
        XCTAssertTrue(equipment.wornItems.isEmpty)
    }

    func test_unequip_frees_the_slot_and_returns_the_item() {
        equipment.equip(TestEquipment.sword)
        let removed = equipment.unequip(itemId: "sword")
        XCTAssertEqual(removed?.code, "sword")
        XCTAssertTrue(equipment.hasRoom(inSlot: "weapon"))
        XCTAssertNil(equipment.unequip(itemId: "sword"))
        XCTAssertTrue(equipment.equipmentSlots.isEmpty)
    }

    func test_worn_items_spans_every_slot_in_a_stable_order() {
        equipment.equip(TestEquipment.helmet)
        equipment.equip(TestEquipment.sword)
        equipment.equip(TestEquipment.item("ring", slot: "trinket", damage: 1))

        XCTAssertEqual(equipment.wornItems.map(\.code), ["helmet", "ring", "sword"])
        for _ in 0 ..< 20 {
            XCTAssertEqual(equipment.wornItems.map(\.code), ["helmet", "ring", "sword"])
        }
    }

    func test_unequip_all_empties_the_body() {
        equipment.equip(TestEquipment.sword)
        equipment.equip(TestEquipment.helmet)
        XCTAssertEqual(Set(equipment.unequipAll().map(\.code)), ["sword", "helmet"])
        XCTAssertTrue(equipment.wornItems.isEmpty)
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
        equipment.equip(TestEquipment.sword)
        equipment.equip(TestEquipment.helmet)
        let data = try JSONEncoder().encode(equipment)
        let decoded = try JSONDecoder().decode(RPEquipment<TestRPSpace>.self, from: data)
        XCTAssertEqual(decoded, equipment)
        XCTAssertEqual(decoded.capacity(ofSlot: "weapon"), 1)
        XCTAssertEqual(decoded.wornItems.map(\.code), ["helmet", "sword"])
    }
}

final class EquipmentSpaceTests: XCTestCase {
    var rpSpace: TestRPSpace!

    override func setUp() {
        rpSpace = TestRPSpace()
        var body = RPBody<TestRPSpace>(["hp": 30])
        body.id = "wearer"
        body.equipment.equipmentSlotCapacities = ["weapon": 1]
        rpSpace.addBody(body)
    }

    func test_equipping_moves_the_item_from_inventory_to_the_body() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        XCTAssertTrue(rpSpace.equipItem(id: "sword", on: "wearer"))

        let wearer = rpSpace.bodyById("wearer")!
        XCTAssertTrue(wearer.inventory.isEmpty)
        XCTAssertEqual(wearer.equipment.wornItems.map(\.code), ["sword"])
        XCTAssertEqual(wearer.cumulativeStats().damage, 10)
    }

    func test_equipping_fails_when_the_slot_is_full_and_leaves_the_item_carried() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.receiveItem(TestEquipment.item("axe", slot: "weapon", damage: 12), to: "wearer")
        XCTAssertTrue(rpSpace.equipItem(id: "sword", on: "wearer"))
        XCTAssertFalse(rpSpace.equipItem(id: "axe", on: "wearer"))

        let wearer = rpSpace.bodyById("wearer")!
        XCTAssertEqual(wearer.inventory.map(\.code), ["axe"])
        XCTAssertEqual(wearer.equipment.wornItems.map(\.code), ["sword"])
    }

    func test_unequipping_returns_the_item_to_inventory() {
        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        XCTAssertTrue(rpSpace.unequipItem(id: "sword", on: "wearer"))

        let wearer = rpSpace.bodyById("wearer")!
        XCTAssertEqual(wearer.inventory.map(\.code), ["sword"])
        XCTAssertTrue(wearer.equipment.wornItems.isEmpty)
        XCTAssertEqual(wearer.cumulativeStats().damage, 0)
    }

    func test_transfer_takes_worn_items_off_the_body() {
        var looter = RPBody<TestRPSpace>(["hp": 30])
        looter.id = "looter"
        rpSpace.addBody(looter)

        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        rpSpace.transferItem(id: "sword", from: "wearer", to: "looter")

        XCTAssertTrue(rpSpace.bodyById("wearer")!.equipment.wornItems.isEmpty)
        XCTAssertEqual(rpSpace.bodyById("looter")!.inventory.map(\.code), ["sword"])
    }

    func test_transfer_all_strips_both_inventory_and_body() {
        var looter = RPBody<TestRPSpace>(["hp": 30])
        looter.id = "looter"
        rpSpace.addBody(looter)

        rpSpace.receiveItem(TestEquipment.sword, to: "wearer")
        rpSpace.receiveItem(TestEquipment.potion, to: "wearer")
        rpSpace.equipItem(id: "sword", on: "wearer")
        rpSpace.transferAllItems(from: "wearer", to: "looter")

        let wearer = rpSpace.bodyById("wearer")!
        XCTAssertTrue(wearer.inventory.isEmpty)
        XCTAssertTrue(wearer.equipment.wornItems.isEmpty)
        XCTAssertEqual(Set(rpSpace.bodyById("looter")!.inventory.map(\.code)), ["sword", "potion"])
    }
}
