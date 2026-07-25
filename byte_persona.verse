using { /Fortnite.com/AI }
using { /Fortnite.com/Playspaces }
using { /UnrealEngine.com/Conversations }
using { /UnrealEngine.com/Temporary/Diagnostics }
using { /Verse.org/Chat }
using { /Verse.org/SceneGraph }
using { /Verse.org/Simulation }
using { /Fortnite.com/Characters }
using { /Fortnite.com/Animation/PlayAnimation }
using { /Fortnite.com/Game }
using { /Verse.org/Assets }
using { /Verse.org/Random }
using { /Verse.org/AgentGroup }
using { /Fortnite.com/Weapons }
using { /UnrealEngine.com/Itemization }
using { /Verse.org/SpatialMath }

S2M<localizes>(value:string) : message="{value}"

eWeapon := enum{PumpShotgun, ShockwaveHammer, HopRockAssaultRifle, None}

responses := struct:
    @ai_description("use the dance field to return if the player asked you to dance")
    Dance: logic
    @ai_description("use the agent field to return the agent speaking to you")
    Agent: ?agent
    @ai_description("use the weapon field to return the weapon the player asked for, output None if not requested or doesn't match")
    Weapon: eWeapon


team_member_data := class(has_voice_member_info) {}
team_agent_group := class(agent_group(team_member_data)){}

new_persona := class(npc_behavior):
    var OptionAgentGroup : ?agent_group(team_member_data ) = false
    var OptionVoiceChannel : ?voice_channel(team_member_data ) = false    
    var Spoken : logic = false

    CreateNPCTeam():void=
        if:
            Agent := GetAgent[]
            SimEntity := Agent.GetSimulationEntity[]
        then:
            TeamGroup:team_agent_group = team_agent_group{}
            TeamVoiceChannel:voice_channel(team_member_data) = voice_channel(team_member_data):
                Name := S2M("Persona Team Chat")
                Group := TeamGroup
            TeamGroup.AddMember(Agent, team_member_data{})
            SimEntity.AddChatChannel(TeamVoiceChannel)
            set OptionAgentGroup = option{TeamGroup}
            set OptionVoiceChannel = option{TeamVoiceChannel}

    AddPlayerAsConversationTarget(Player:player):void=
        if: 
            NPCEntity := GetEntity[]
            NPCAgent := GetAgent[]
            SimEntity := Player.GetSimulationEntity[]
            PersonaComponent := NPCEntity.GetComponent[persona_component]
            AgentGroup := OptionAgentGroup?
            VoiceChannel := OptionVoiceChannel?
            AISession:=PersonaComponent.GetAISession()
        then:           
            for ( Channel : SimEntity.GetVoiceChannels() ):
                if (Channel.Group.GetMemberMap()[Player]):
                    if (PlayerAgentGroup := team_agent_group[Channel.Group]):
                        PlayerAgentGroup.RemoveMember(Player)
            AgentGroup.AddMember(Player, team_member_data{})
            Player.SetConversationTarget(PersonaComponent, VoiceChannel)    
            BindingDef:prompt_binding_definition=prompt_binding_definition{Name:=S2M("InteractionBinding"), Description:=S2M("Signals whenever the player has spoken to you.")}   
            AISession.RegisterAction(BindingDef,true,responses,AIResponse)
            
    AIResponse(Responses:responses):void=
        if: 
            Responses.Dance = true 
            NPCFC:=GetAgent[].GetFortCharacter[]
        then:
            spawn. DoDance(NPCFC)
        
        var Weapon:entity=entity{}
        case(Responses.Weapon):
            eWeapon.PumpShotgun => 
                set Weapon=PumpShotgun_OG_CH1S6_Legendary{}
            eWeapon.ShockwaveHammer => 
                set Weapon=ShockwaveHammer_BR_CH4S1_Epic{}
            eWeapon.HopRockAssaultRifle => 
                set Weapon=EradicatorHopRockFuryAssaultRifle_BR_CH6S4_Exotic{}
            eWeapon.None => "" 

        if:
            Agent:=Responses.Agent?
            Inv:=first{Comp:Agent.FindDescendantComponents(inventory_component)}
        then:
            Inv.AddItemDistribute(Weapon)

    IntroLoop()<suspends>:void=
        if:
            SimEnt:=GetEntity[].GetSimulationEntity[]
            PersonaComp:=GetEntity[].GetComponent[persona_component]
            Camera:=first{Comp:SimEnt.FindDescendantComponents(camera_component)}
        then:
            mPlayer:=PersonaComp.StartSayEvent.Await()
            if:
                Player:=player[mPlayer(0)?]
                Director:=Player.GetComponent[camera_director_component]
                Cancelable:=Director.AddCamera[Camera,100]    
                NPCFC:=GetAgent[].GetFortCharacter[]
                AC:=NPCFC.GetPlayAnimationController[]
            then:
                AnimStop:=AC.Play(NPC_Idle, ?BlendInTime:=0.5, ?BlendOutTime:=0.5, ?PlayCount:=100.0)
                PersonaComp.StopSayEvent.Await()
                AnimStop.Stop()
                Cancelable.Cancel()
                spawn. NaviLoop()   

    DoDance(FC:fort_character)<suspends>:void=
        if(AC:=FC.GetPlayAnimationController[], SimEntity:=GetEntity[].GetSimulationEntity[]):
            NewEntity:=entity{}
            NewComp:=MSS_Sound{Entity:=NewEntity, AutoPlay:=false, Sounds:=array{hip_asset}}
            NewEntity.AddComponents(array. NewComp)
            SimEntity.AddEntities(array. NewEntity)
            NewComp.Play()
            FC.PutInStasis(stasis_args{})
            AC.PlayAndAwait(NPC_Anim, ?BlendInTime:=0.5, ?BlendOutTime:=0.5)
            NewComp.Stop()
            NewEntity.RemoveFromParent()
            FC.ReleaseFromStasis()

    OnDamaged(Result:damage_result):void=
        spawn. OnDamagedSuspends(Result)

    OnDamagedSuspends(Result:damage_result)<suspends>:void=
        NewPrompt:=S2M("The player just shot you.  Tell them you don't like it and not to do it again")
        if:
            PersonaComponent := GetEntity[].GetComponent[persona_component]    
            VoiceChannel := OptionVoiceChannel?
            FC:=GetAgent[].GetFortCharacter[]
            FC.PutInStasis(stasis_args{})
            PersonaComponent.PromptToTalk[NewPrompt, VoiceChannel]
        then:
            PersonaComponent.StopSayEvent.Await()
            FC.ReleaseFromStasis()

    NaviLoop()<suspends>:void=
        if:
            Agent:=GetAgent[]
            Actions:=GetEntity[].GetComponent[npc_actions_component]
            PersonaComp:=GetEntity[].GetComponent[persona_component]
            StartLocation := GetEntity[].GetGlobalTransform().Translation
        then:
            Radius := 750.0
            loop:
                var TriggeringPlayer:?agent = false
                race:
                    loop:
                        Sleep(GetRandomFloat(3.0,4.0))
                        RandomLeft:=GetRandomFloat(-Radius,Radius)
                        RandomForward:=GetRandomFloat(-Radius,Radius)
                        TargetLocation:=vector3{Left:=RandomLeft, Up:=StartLocation.Up, Forward:=RandomForward}
                        NavTarget:=MakeNavigationTarget(TargetLocation)
                        NavResult := Actions.NavigateTo(NavTarget)
                    block:
                        Player:=PersonaComp.StartHearEvent.Await()
                        set TriggeringPlayer = option. Player

                Actions.StopNavigation()
                
                race:
                    block:
                        if (PlayerEnt := TriggeringPlayer?.GetFortCharacter[].GetEntity[]):
                            Actions.Focus(PlayerEnt, ?LockFocus := true)
                    PersonaComp.StopSayEvent.Await()                    



    RemovePlayerAsConversationTarget(Player:player):void=
        Player.ClearConversationTarget()

    OnBegin<override>()<suspends>:void=
        CreateNPCTeam()
        Sleep(0.1)
        for (Player : GetEntity[].GetPlayspaceForEntity[].GetPlayers()):
            AddPlayerAsConversationTarget(Player)
        
        if(FC:=GetAgent[].GetFortCharacter[]):
            FC.DamagedEvent().Subscribe(OnDamaged)      

        spawn. IntroLoop()
        
    OnEnd<override>():void=
        for (Player : GetEntity[].GetPlayspaceForEntity[].GetPlayers()):
            RemovePlayerAsConversationTarget(Player)