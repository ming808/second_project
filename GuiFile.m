classdef GuiFile< interfaces.GuiModuleInterface & interfaces.LocDataInterface
    properties
        autosavetimer
        %test
        loaders
        savers
    end
    methods
        function obj=GuiFile(varargin)
            obj@interfaces.GuiModuleInterface(varargin{:})
            obj.outputParameters={'group_dx','group_dt'};
        end
        function initGui(obj)
            obj.loaders=plugintemp.plugins('loaderssavers','ploaders');
            lp={};
            for k=1:length(obj.loaders)
                infom=plugintemp.plugins('loaderssavers','ploaders',obj.loaders{k});
                info=infom.info;
                lp{k}=info.name;
            end
            obj.guihandles.loadmodule.String=lp;
            
            obj.savers=plugintemp.plugins('loaderssavers','psavers');
            for k=1:length(obj.savers)
                info=plugintemp.plugins('loaderssavers','psavers',obj.savers{k}).info;
                ls{k}=info.name;
            end 
            obj.guihandles.savemodule.String=ls;
            obj.addhandle('filelist_long',obj.guihandles.filelist_long,'String');
        end
     
        function loadbutton_callback(obj, handle,actiondata,isadd)
            %load data 
            p=obj.getAllParameters;
            fm=p.mainfile;   
            if isempty(fm)
                fm=p.filelist_long.selection;
            end
            path=fileparts(fm);          
            loader=plugintemp.plugins('loaderssavers','ploaders',obj.loaders{p.loadmodule.Value},[],obj.P);
            try
                 ext=loader.info.extensions;
                 title=loader.info.dialogtitle;
            catch
                ext='*.*';
                title='format not specified'
            end
            [f,pfad]=uigetfile(ext,title,path);
            if f %file selected
                obj.status('load file')
                drawnow
                mode=modules.files.getfilemode([pfad f]);
                if strcmp(mode,'tif')
                    si=modules.files.checkforsingleimages([pfad f]);             
                    if ~isempty(si)
                        obj.setPar('filelist_localize',[pfad f]) %communication with localizer
                        maing=obj.getPar('mainGui');
                        maing.setmaintab(2);
                        return
                    end
                end

                if ~isadd && strcmp(mode,'sml')%clear locData  
                    obj.locData.empty;
                else
                    obj.locData.empty('filter');
                end
                
                loader.attachLocData(obj.locData);
                par=obj.getAllParameters(loader.inputParameters);
                loader.load(par,[pfad f]);
%                 loadfile(obj,[p f],mode)
                obj.status('file loaded')
%                 obj.locData.filter;
            end 
            autosavecheck_callback(0,0,obj)
        end
        
       
        
        function remove_callback(obj,handle,actiondata)
            disp('remove_callback in GuiFile not implemented')
%             fv=get(obj.handle.filelist,'Value');
%             fl=get(obj.handle.filelist,'String');
%             fl{fv}=[];
%             set(obj.handle.filelist,'String',fl); 
            
        end     
        
        function setGuiParameters(obj,p,setchildren)
            setGuiParameters@interfaces.GuiModuleInterface(obj,p,setchildren);
            obj.guihandles.filelist_long.String=p.filelist_long.String;      
           
        end
        function group_callback(obj,a,b)
            obj.locData.regroup;
%             group_callback(0, 0,obj);
        end
        function pard=pardef(obj)
            pard=pardef(obj);
        end
        function delete(obj)
            delete(obj.autosavetimer)
        end
    end
end

% function group_callback(object, event,obj)
% obj.locData.regroup;
% end

function save_callback(objcet,event,obj)
p=obj.getAllParameters;
saver=plugintemp.plugins('loaderssavers','psavers',obj.savers{p.savemodule.Value},[],obj.P);
psave=obj.getAllParameters(saver.inputParameters);
saver.attachLocData(obj.locData);
saver.save(psave);

end



function imout=gettif(file)
imout.image=imread(file); 
sim=size(imout.image);
imout.info.Width=sim(1);
imout.info.Height=sim(2);
imout.info.roi=modules.files.getRoiTif(file);
imout.info.name=file;
end

function savemode_callback(data,b,obj)
switch data.String{data.Value}
    case {'_fitpos','_sml'}
        obj.setPar('file_saveoption','on','Visible','only save visible','String',0,'Value')      
    otherwise
        obj.setPar('file_saveoption','off','Visible')
end
end

function autosavecheck_callback(a,b,obj)
p=obj.getAllParameters;
t=obj.autosavetimer;
%creaste timer if empty or invalid
if isempty(t)||~isa(t,'timer')||~isvalid(t)
    t=timer;
    t.Period=p.autosavetime*60;
    t.StartDelay=t.Period;
    t.TimerFcn={@autosave_timer,obj};
    t.ExecutionMode='fixedRate';
    obj.autosavetimer=t;
end

if p.autosavecheck %deactivate
    if strcmpi(t.Running,'off')
    start(t);
    end
else
    if strcmpi(t.Running,'on')
    stop(t);
    end
end
end

function autosave_timer(a,b,obj)
p.mainGui=obj.getPar('mainGui');
p.saveroi=false;
if obj.guihandles.autosavecheck.Value
    modules.files.savesml(obj.locData,'autosave_sml',p)
    time=datetime('now');
    disp(['autosave: ' num2str(time.Hour) ':' num2str(time.Minute)])
end
end

function autosavetime_callback(a,b,obj)
p=obj.getGuiParameters;
t=obj.autosavetimer;
if ~isempty(t)||isa(t,'timer')
    if strcmpi(t.Running,'on')
        stop(t);
    end
    obj.autosavetimer.Period=p.autosavetime*60;
    obj.autosavetimer.StartDelay=obj.autosavetimer.Period;
    if obj.guihandles.autosavecheck.Value
        start(t);
    end
end
end

function pard=pardef(obj)
pard.load.object=struct('Style','pushbutton','String','Load','Callback',{{@obj.loadbutton_callback,0}});
pard.load.position=[4.5,1];
pard.load.Width=0.75;
pard.load.Height=1.5;

pard.add.object=struct('Style','pushbutton','String','Add','Callback',{{@obj.loadbutton_callback,1}});
pard.add.position=[4.5,1.75];
pard.add.Width=0.75;
pard.add.Height=1.5;

pard.loadmodule.object=struct('Style','popupmenu','String',{'auto'});
pard.loadmodule.position=[5.5,1];
 pard.loadmodule.Width=1.5;


pard.remove.object=struct('Style','pushbutton','String','remove','Callback',{{@obj.remove_callback,1}});
pard.remove.position=[4,4.5];
pard.remove.Width=0.5;
% pard.add.Height=1.5;


pard.filelist_long.object=struct('Style','Listbox','String',{'x://'});
pard.filelist_long.position=[3,1];
pard.filelist_long.Width=4;
pard.filelist_long.Height=3;

pard.autosavecheck.object=struct('Style','checkbox','String','Auto save (min):','Value',1);
pard.autosavecheck.position=[10,3.5];
pard.autosavecheck.Width=1.3;

pard.autosavetime.object=struct('Style','edit','String','10','Callback',{{@autosavetime_callback,obj}});
pard.autosavetime.position=[10,4.5];
pard.autosavetime.Width=0.5;

pard.savemodule.object=struct('Style','popupmenu','String',{{'_sml','final image','raw images','_fitpos','settings'}},...
    'Callback',{{@savemode_callback,obj}});
pard.savemodule.position=[8,1.];
pard.savemodule.Width=1.5;

pard.save.object=struct('Style','pushbutton','String','Save','Callback',{{@save_callback,obj}});
pard.save.position=[7,1];
pard.save.Width=.75;

pard.file_saveoption.object=struct('Style','checkbox','String','saveoptions:','Visible','on');
pard.file_saveoption.position=[9,1];
pard.file_saveoption.Width=1.5;


pard.group_b.object=struct('Style','pushbutton','String','Group','Callback',{{@obj.group_callback}});
pard.group_b.position=[6,3.5];
pard.group_b.Width=1.5;
% pard.group_b.Height=1.5;

pard.group_tdx.object=struct('Style','text','String','dX (nm)');
pard.group_tdx.position=[7,3.5];
pard.group_dx.object=struct('Style','edit','String','75');
pard.group_dx.position=[7,4.5];
pard.group_dx.Width=0.5;

pard.group_tdt.object=struct('Style','text','String','dT (frames)');
pard.group_tdt.position=[8,3.5];
pard.group_dt.object=struct('Style','edit','String','0');
pard.group_dt.position=[8,4.5];
pard.group_dt.Width=0.5;
%for test change
%change in branch iss53
%finish iss53
