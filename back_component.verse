using { /Verse.org }
using { /Verse.org/Native }
using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Verse.org/Input }
using { /Verse.org/Input/UI }
using { /Fortnite.com/Devices }
using { /Verse.org/Assets }
using { /UnrealEngine.com/Temporary/UI }

back_component<public> := class<final_super>(component):

    @editable Trigger : trigger_device = trigger_device{}
    Widget:wBackTest = wBackTest{}

    TriggerAwait()<suspends>:void=
        loop:
            mAgent:=Trigger.TriggeredEvent.Await()
            if:
                Agent:=mAgent?
                Player:=player[Agent]
                PlayerInput:=GetPlayerInput[Player]
                PlayerUI:=GetPlayerUI[Player]
            then:
                PlayerUI.AddWidget(Widget, player_ui_slot{InputMode := ui_input_mode.All})
                PlayerInput.AddInputMapping(UI.MenuNavigationMapping);
                InputEvents := PlayerInput.GetInputEvents(UI.Back)
                spawn. DetectInputs(Player,InputEvents)

    DetectInputs(Player:player,InputEvents:input_events(logic))<suspends>:void=    
        InputEvents.TriggerActivationEvent.Await()
        if(PlayerUI:=GetPlayerUI[Player], PlayerInput:=GetPlayerInput[Player]):
            PlayerUI.RemoveWidget(Widget)
            PlayerInput.RemoveInputMapping(UI.MenuNavigationMapping)
        Sleep(0.0)

    OnBeginSimulation<override>():void =
        (super:)OnBeginSimulation()

    OnSimulate<override>()<suspends>:void =
        spawn. TriggerAwait()
        

