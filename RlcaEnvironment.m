classdef RlcaEnvironment < handle
    %ENVIRONMENT Summary of this class goes here
    %   Detailed explanation goes here
    
    properties
        Agents = cell(0);
        nAgents = 0;
        time = 0;
        Gui
    end
    
    methods
        function obj = RlcaEnvironment(Gui)
            obj.Gui = Gui;
            
        end
        
        function obj = run(obj)
            for t = EnvironmentConstants.tStart:EnvironmentConstants.tStep:EnvironmentConstants.tEnd
                obj.updateagents();
                obj.Gui = obj.Gui.updateGui(obj.Agents,obj.nAgents);
            end
            
        end
        
        function obj = timestep(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
            for iAgent = 1:obj.nAgents
               obj.Agents(iAgent).timeStep(EnvironmentConstants.stepSize); 
            end
        end
        
        function [] = createagent(obj,x0,y0,xg,yg)
           iAgent = obj.nAgents + 1;
           obj.Agents{iAgent} = RlcaAgent(x0,y0,xg,yg,iAgent);
           obj.nAgents = iAgent;
           
                       
           obj.Gui.generateagentgraphic(obj.Agents{iAgent});

        end
        
        function obj = updateagents(obj)
           for iAgent = 1:obj.nAgents
              obj.Agents{iAgent} = obj.Agents{iAgent}.timeStep(); 
           end
           
        end
        
    end
end

