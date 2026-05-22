using { /Verse.org }
using { /Verse.org/Native }
using { /Verse.org/SceneGraph }
using { /Verse.org/SpatialMath }
using { /Verse.org/Simulation }
using { /Fortnite.com/Devices }
using { /Fortnite.com/Itemization }
using { /UnrealEngine.com/Itemization }
using { /UnrealEngine.com/Temporary/UI }
using { /Fortnite.com/Weapons }
using { /Fortnite.com/Characters }

items_to_grant<public>:=class:
    @editable Item : subtype(entity) = false
    @editable Amount : int = 1
    
item_granter_component<public> := class<final_super>(component):

    @editable Trig : trigger_device = trigger_device{}
    @editable Items : []items_to_grant = array{}
    @editable ClearInventory : logic = false
    @editable EquipGranted : logic = true

    TriggerAwait()<suspends>:void=
        loop:
            mAgent:=Trig.TriggeredEvent.Await()
            if:
                Agent:=mAgent?
                PlayerUI:=GetPlayerUI[player[Agent]]
                InvGen:=Agent.FindDescendantComponents(inventory_component)
                Inventory:=(for(InvComp:InvGen) do InvComp)[0]
                Hotbar:=(for(InvComp:InvGen, fort_inventory_weapon_hotbar_component[InvComp]) do InvComp)[0]
                SimEnt:=Entity.GetSimulationEntity[]
            then:
                if(ClearInventory?):
                    for (Inv:InvGen, not fort_inventory_harvest_tool_component[Inv]):
                        InvItems:=Inv.GetItems()
                        for (InvItem:InvItems):
                            Inv.RemoveItem(InvItem)

                for (Item:Items):
                    ItemConcrete: concrete_subtype(entity) = Item.Item
                    ItemToGrant := ItemConcrete{}
                    
                    if(Stack:=ItemToGrant.GetComponent[stackable_component]):
                        if (MaxStack:=Stack.MaxStackSize?, Item.Amount>MaxStack):
                            Stack.SetStackSize(MaxStack)
                        else:
                            Stack.SetStackSize(Item.Amount)
                        Result:=Inventory.AddItemDistribute(ItemToGrant)
                        if. Result.GetError[] then spawn. GrantFailed(Hotbar, Inventory, SimEnt, Agent, ItemToGrant)
                        Sleep(0.1)
                        if(EquipGranted?, ItemComp:=ItemToGrant.GetComponent[item_component]) then ItemComp.Equip()
                    else:
                        for (I:=0..Item.Amount-1):
                            LoopItem := ItemConcrete{}
                            Result:=Inventory.AddItemDistribute(LoopItem)
                            if. Result.GetError[] then spawn. GrantFailed(Hotbar, Inventory, SimEnt, Agent, ItemToGrant)
                            Sleep(0.1)
                            if(EquipGranted?, ItemComp:=LoopItem.GetComponent[item_component]) then ItemComp.Equip()
            Sleep(0.0)
                                
    GrantFailed(Hotbar:inventory_component, Inventory:inventory_component, SimEnt:entity, Agent:agent, ItemToGrant:entity)<suspends>:void=
        EquippedItems:=Hotbar.GetEquippedItems()
        if(EquippedItem:=EquippedItems[0], not ItemToGrant.GetComponent[stackable_component]):
            Inventory.RemoveItem(EquippedItem)
            SimEnt.AddEntities(array{EquippedItem})
            EquippedItem.SetGlobalTransform(GetPlayerLoc(Agent,100.0))
            Inventory.AddItemDistribute(ItemToGrant)
            Sleep(0.0)
            if(EquipGranted?, ItemComp:=ItemToGrant.GetComponent[item_component]) then ItemComp.Equip()
        else:
            SimEnt.AddEntities(array{ItemToGrant})
            ItemToGrant.SetGlobalTransform(GetPlayerLoc(Agent,100.0))

    GetPlayerLoc(Agent:agent, Dist:float):transform=
        if:
            FCEnt:=Agent.GetFortCharacter[].GetEntity[]
        then:
            XForm:=FCEnt.GetGlobalTransform()
            LocalForward:=XForm.Rotation.GetForwardAxis()*Dist
            NewXForm:=transform:
                Translation:=XForm.Translation+LocalForward
            NewXForm
        else:
            transform{}
                   
    OnBeginSimulation<override>():void =
        (super:)OnBeginSimulation()

    OnSimulate<override>()<suspends>:void =
        spawn. TriggerAwait()


