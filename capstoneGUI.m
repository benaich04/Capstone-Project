function fig = capstoneGUI()
%CAPSTONEGUI Interactive, draggable Wi-Fi TDoA capstone dashboard (R2026a).
% Run: capstoneGUI          or: launchGUI
% Drag the TX (gold), any RX (blue), or a wall (purple). To add a wall,
% press "Add wall" and click two points. Run/Step executes REAL Blocks 1-5.
% Original team algorithms and all function signatures remain unchanged.
% WLAN Toolbox is required by the original transmitter and receiver blocks.

projectDir = fileparts(mfilename('fullpath'));
addpath(projectDir);
app = struct();
app.cfg = config();
app.startConfig = app.cfg;
app.running = false;
app.stopRequested = false;
app.paused = false;
app.drag = [];
app.wallFirst = [];
app.addingWall = false;
app.showHyperbolas = true;
app.playbackDelay = 0.15;  % UI refresh pause, distinct from cfg.dt
app.last = [];
app.mc = [];
app.state = [];
app.Ppred = [];
app.k = 0;
app.history = blankHistory();
app.logLines = {'GUI opened. Drag TX/RX markers, configure sliders, then Run.'};
app.lockables = {};
app.sceneBounds = initialBounds(app.cfg);
app.palette.blue = [0.11 0.40 0.76];
app.palette.gold = [0.92 0.60 0.15];
app.palette.red = [0.87 0.24 0.24];
app.palette.purple = [0.55 0.31 0.72];
app.palette.teal = [0.06 0.59 0.50];

screenSize=get(0,'ScreenSize');
w=min(1530,max(980,screenSize(3)-60));
h=min(910,max(720,screenSize(4)-90));
fig = uifigure('Name','Wi-Fi ISAC | Interactive TDoA Localization', ...
    'Position',[max(1,round((screenSize(3)-w)/2)) ...
                max(1,round((screenSize(4)-h)/2)) w h], ...
    'Color',[0.967 0.976 0.989]);
fig.CloseRequestFcn = @closeApp;
fig.WindowButtonMotionFcn = @mouseMove;
fig.WindowButtonUpFcn = @mouseUp;

root = uigridlayout(fig,[3 1]);
root.RowHeight = {60,'1x',30};
root.ColumnWidth = {'1x'};
root.Padding = [12 8 12 8];
root.RowSpacing = 9;

head = uigridlayout(root,[1 3]);
head.Layout.Row = 1;
head.ColumnWidth = {'1.6x','1x',180};
head.RowHeight = {'1x'};
head.Padding = [8 0 8 0];
head.BackgroundColor = [1 1 1];
app.title = uilabel(head,'Text','Wi-Fi  /  TDoA Localization Lab', ...
    'FontSize',21,'FontWeight','bold','FontColor',[0.12 0.21 0.33]);
app.title.Layout.Column=1;
app.status = uilabel(head,'Text','READY  |  Scene editable', ...
    'FontSize',12,'FontWeight','bold','FontColor',app.palette.teal, ...
    'HorizontalAlignment','center');
app.status.Layout.Column=2;
app.helpBtn = uibutton(head,'push','Text','?   HOW TO USE', ...
    'ButtonPushedFcn',@showHelp);
app.helpBtn.Layout.Column=3;

body = uigridlayout(root,[1 3]);
body.Layout.Row=2;
body.ColumnWidth = {333,'2.4x','1.35x'};
body.RowHeight = {'1x'};
body.ColumnSpacing=10;
body.Padding=[0 0 0 0];

app.controlTabs=uitabgroup(body);
app.controlTabs.Layout.Column=1;
setupControls();

middle=uigridlayout(body,[2 1]);
middle.Layout.Column=2;
middle.RowHeight={'3x','1x'};
middle.ColumnWidth={'1x'};
middle.RowSpacing=9;
middle.Padding=[0 0 0 0];

scenePanel=uipanel(middle,'Title','INTERACTIVE 2D SCENE  -  drag TX / RX / walls', ...
    'FontWeight','bold','BackgroundColor','white');
scenePanel.Layout.Row=1;
% The axes resize automatically with the figure.
sceneGrid=uigridlayout(scenePanel,[1 1], ...
    'RowHeight',{'1x'},'ColumnWidth',{'1x'},'Padding',[7 5 7 4]);
app.mapAx=uiaxes(sceneGrid);
app.mapAx.Layout.Row=1;
app.mapAx.ButtonDownFcn=@mapClick;
try
    disableDefaultInteractivity(app.mapAx);
catch
    % Custom drag callbacks still work when older environments lack this API.
end

errPanel=uipanel(middle,'Title','POSITION ERROR / TRACKING HISTORY', ...
    'FontWeight','bold','BackgroundColor','white');
errPanel.Layout.Row=2;
errGrid=uigridlayout(errPanel,[1 1],'Padding',[6 4 6 3]);
app.errorAx=uiaxes(errGrid);

right=uigridlayout(body,[2 1]);
right.Layout.Column=3;
right.RowHeight={150,'1x'};
right.Padding=[0 0 0 0];
right.RowSpacing=9;
app.summary=uitextarea(right,'Editable','off', ...
    'Value',{'No processed packets yet.','Run a packet to show estimates.'}, ...
    'FontName','Courier New','FontSize',12);
app.summary.Layout.Row=1;
app.resultTabs=uitabgroup(right);
app.resultTabs.Layout.Row=2;
setupOutputTabs();

app.footer=uilabel(root, ...
    'Text','Tip: Click Add wall, then two points. The supplied Block 1 reflects signals but does not attenuate obstructed LoS.', ...
    'FontSize',11,'FontColor',[0.30 0.37 0.45]);
app.footer.Layout.Row=3;

resetPlots();
drawMap();
setBusy(false);
appendLog('Loaded shared config.m; original five-block MATLAB chain is ready.');

    function setupControls()
        runTab=uitab(app.controlTabs,'Title','Run');
        rfTab=uitab(app.controlTabs,'Title','RF + Tracking');
        sceneTab=uitab(app.controlTabs,'Title','Scene Editor');

        r=uigridlayout(runTab,[15 3]);
        r.ColumnWidth={97,'1x',57};
        r.RowHeight={27,38,38,39,39,39,38,38,38,38,38,38,38,48,'1x'};
        r.RowSpacing=5; r.Padding=[11 10 11 8];
        titleRow(r,1,'SIMULATION CONTROLS');
        labelAt(r,2,'Mode');
        app.modeDrop=uidropdown(r,'Items',{'stationary','moving'}, ...
            'Value',app.cfg.experimentMode,'ValueChangedFcn',@modeChanged);
        setSpan(app.modeDrop,2,[2 3]); lockable(app.modeDrop);
        labelAt(r,3,'Fusion output');
        app.fusionDrop=uidropdown(r,'Items',{'kalman','window','cumulative'}, ...
            'Value',app.cfg.fusionOutput,'ValueChangedFcn',@fusionChanged);
        setSpan(app.fusionDrop,3,[2 3]); lockable(app.fusionDrop);
        addSlider(r,4,'Packets','Npackets',[1 75],'%.0f',true);
        addSlider(r,5,'Animate (s)','playbackDelay',[0 1],'%.2f',false);
        addSlider(r,6,'Packet dt (s)','dt',[0.02 0.6],'%.2f',false);
        app.btnStep=uibutton(r,'push','Text','STEP ONE PACKET', ...
            'FontWeight','bold','ButtonPushedFcn',@stepClicked);
        setSpan(app.btnStep,7,[1 3]); lockable(app.btnStep);
        app.btnRun=uibutton(r,'push','Text','RUN FULL SEQUENCE', ...
            'BackgroundColor',[0.11 0.40 0.76],'FontColor','white', ...
            'FontWeight','bold','ButtonPushedFcn',@runClicked);
        setSpan(app.btnRun,8,[1 3]); lockable(app.btnRun);
        app.btnStop=uibutton(r,'push','Text','STOP', ...
            'ButtonPushedFcn',@stopClicked,'BackgroundColor',[1 0.88 0.88]);
        setSpan(app.btnStop,9,[1 2]);
        app.btnReset=uibutton(r,'push','Text','Reset', ...
            'ButtonPushedFcn',@resetClicked);
        setSpan(app.btnReset,9,3);lockable(app.btnReset);
        app.btnPause=uibutton(r,'push','Text','PAUSE / RESUME', ...
            'ButtonPushedFcn',@pauseClicked);
        setSpan(app.btnPause,10,[1 3]);
        app.btnSave=uibutton(r,'push','Text','Save session (.mat)', ...
            'ButtonPushedFcn',@saveClicked);
        setSpan(app.btnSave,11,[1 3]); lockable(app.btnSave);
        app.btnCSV=uibutton(r,'push','Text','Export history (.csv)', ...
            'ButtonPushedFcn',@csvClicked);
        setSpan(app.btnCSV,12,[1 3]); lockable(app.btnCSV);
        app.btnPNG=uibutton(r,'push','Text','Export scene (.png)', ...
            'ButtonPushedFcn',@imageClicked);
        setSpan(app.btnPNG,13,[1 3]); lockable(app.btnPNG);
        note=uilabel(r,'Text', ...
            sprintf(['STEP continues a current run. FULL RUN resets the sequence.\n' ...
            'Changing the scene or settings resets tracking history.']), ...
            'FontSize',11,'FontColor',[0.35 0.40 0.47]);
        setSpan(note,14,[1 3]);

        a=uigridlayout(rfTab,[17 3]);
        a.ColumnWidth={106,'1x',59};
        a.RowHeight={25,38,38,38,38,38,38,38,38,38,38,38,38,38,38,45,'1x'};
        a.RowSpacing=4; a.Padding=[11 9 11 9];
        titleRow(a,1,'CHANNEL / ESTIMATOR SETTINGS');
        labelAt(a,2,'Wi-Fi band');
        app.bwDrop=uidropdown(a,'Items',{'CBW20','CBW40','CBW80'}, ...
            'Value',app.cfg.cbw,'ValueChangedFcn',@bandChanged);
        setSpan(app.bwDrop,2,[2 3]); lockable(app.bwDrop);
        addSlider(a,3,'TX power (dBm)','Pt_dBm',[-25 15],'%.0f',true);
        addSlider(a,4,'RX NF (dB)','NF_dB',[0 20],'%.0f',true);
        addSlider(a,5,'CIR pad factor','zpFactor',[2 32],'%.0f',true);
        addSlider(a,6,'Reflection (dB)','reflLoss_dB',[0 24],'%.0f',true);
        addSlider(a,7,'Speed X (m/s)','vx',[-3 3],'%.2f',false);
        addSlider(a,8,'Speed Y (m/s)','vy',[-3 3],'%.2f',false);
        addSlider(a,9,'Track accel','trackAccelStd',[0.05 2.5],'%.2f',false);
        addSlider(a,10,'Window packets','windowLength',[5 30],'%.0f',true);
        addSlider(a,11,'Window decay','windowDecay',[0.70 1],'%.2f',false);
        addSlider(a,12,'MC trials','Nmc',[2 100],'%.0f',true);
        labelAt(a,13,'First path');
        app.pathDrop=uidropdown(a,'Items',{'sic','threshold'}, ...
            'Value',app.cfg.firstPathMethod,'ValueChangedFcn',@pathChanged);
        setSpan(app.pathDrop,13,[2 3]); lockable(app.pathDrop);
        app.btnMC=uibutton(a,'push','Text','RUN MONTE CARLO', ...
            'FontWeight','bold','ButtonPushedFcn',@mcClicked);
        setSpan(app.btnMC,15,[1 3]); lockable(app.btnMC);
        note=uilabel(a,'Text', ...
            'Physical Wi-Fi bandwidth changes sample rate. CIR zero padding only interpolates the delay grid.', ...
            'WordWrap','on','FontSize',10,'FontColor',[0.35 0.40 0.47]);
        setSpan(note,16,[1 3]);

        s=uigridlayout(sceneTab,[15 3]);
        s.ColumnWidth={94,'1x',75};
        s.RowHeight={43,37,37,25,148,36,36,36,36,36,36,37,28,'1x',6};
        s.RowSpacing=5; s.Padding=[11 9 11 8];
        note=uilabel(s,'Text', ...
            'Drag gold TX, blue RX triangles, or purple wall segments on the map.', ...
            'WordWrap','on','FontSize',12,'FontWeight','bold');
        setSpan(note,1,[1 3]);
        labelAt(s,2,'TX X (m)');
        app.txX=uieditfield(s,'numeric','Value',app.cfg.P0(1), ...
            'ValueChangedFcn',@txEditChanged);
        setSpan(app.txX,2,[2 3]); lockable(app.txX);
        labelAt(s,3,'TX Y (m)');
        app.txY=uieditfield(s,'numeric','Value',app.cfg.P0(2), ...
            'ValueChangedFcn',@txEditChanged);
        setSpan(app.txY,3,[2 3]); lockable(app.txY);
        titleRow(s,4,'RECEIVER COORDINATES (m)');
        app.rxTable=uitable(s,'Data',app.cfg.Rx, ...
            'ColumnName',{'X (m)','Y (m)'},'RowName',{'RX1','RX2','RX3','RX4'}, ...
            'ColumnEditable',[true true],'CellEditCallback',@rxEdited);
        setSpan(app.rxTable,5,[1 3]); lockable(app.rxTable);
        app.btnAddWall=uibutton(s,'push','Text','Add wall: 2 clicks', ...
            'ButtonPushedFcn',@addWallClicked);
        setSpan(app.btnAddWall,6,[1 3]); lockable(app.btnAddWall);
        app.btnDelWall=uibutton(s,'push','Text','Remove last wall', ...
            'ButtonPushedFcn',@removeWallClicked);
        setSpan(app.btnDelWall,7,[1 3]); lockable(app.btnDelWall);
        app.btnClearWall=uibutton(s,'push','Text','Clear all walls', ...
            'ButtonPushedFcn',@clearWallsClicked);
        setSpan(app.btnClearWall,8,[1 3]); lockable(app.btnClearWall);
        app.btnFit=uibutton(s,'push','Text','Fit map', ...
            'ButtonPushedFcn',@fitClicked);
        setSpan(app.btnFit,9,[1 2]);lockable(app.btnFit);
        app.btnZoomIn=uibutton(s,'push','Text','Zoom +', ...
            'ButtonPushedFcn',@zoomInClicked);
        setSpan(app.btnZoomIn,9,3);lockable(app.btnZoomIn);
        app.btnZoomOut=uibutton(s,'push','Text','Zoom -', ...
            'ButtonPushedFcn',@zoomOutClicked);
        setSpan(app.btnZoomOut,10,[1 3]);lockable(app.btnZoomOut);
        app.showHyperCB=uicheckbox(s,'Text','Show TDoA hyperbolas', ...
            'Value',true,'ValueChangedFcn',@hyperChanged);
        setSpan(app.showHyperCB,11,[1 3]);lockable(app.showHyperCB);
        app.btnResetScene=uibutton(s,'push','Text','Restore default scene', ...
            'ButtonPushedFcn',@restoreSceneClicked);
        setSpan(app.btnResetScene,12,[1 3]);lockable(app.btnResetScene);
        app.sceneHint=uilabel(s,'Text','Click Add wall, then two empty map points.', ...
            'FontSize',10,'FontColor',[0.4 0.38 0.48]);
        setSpan(app.sceneHint,13,[1 3]);
    end

    function setupOutputTabs()
        tbSig=uitab(app.resultTabs,'Title','Signals');
        tbLoc=uitab(app.resultTabs,'Title','Localization');
        tbDiag=uitab(app.resultTabs,'Title','Diagnostics');
        tbMC=uitab(app.resultTabs,'Title','Monte Carlo');
        sg=uigridlayout(tbSig,[3 1],'RowHeight',{'1x','1x','1x'},'Padding',[4 4 4 4]);
        app.waveAx=uiaxes(sg); app.csiAx=uiaxes(sg); app.cirAx=uiaxes(sg);
        lg=uigridlayout(tbLoc,[3 1],'RowHeight',{'1x','1x','1x'},'Padding',[4 4 4 4]);
        app.tdoaAx=uiaxes(lg);app.locErrorAx=uiaxes(lg);app.covAx=uiaxes(lg);
        dg=uigridlayout(tbDiag,[5 1]);
        dg.RowHeight={24,165,24,140,'1x'};
        dg.Padding=[6 6 6 6];
        d1=uilabel(dg,'Text','RECEIVER QUALITY (relative CIR timing)','FontWeight','bold');
        d1.Layout.Row=1;
        app.rxDiagTable=uitable(dg,'Data',nan(4,4), ...
            'ColumnName',{'RX','Distance (m)','CIR tau (ns)','SNR 1st (dB)'}, ...
            'ColumnEditable',[false false false false]);
        app.rxDiagTable.Layout.Row=2;
        d2=uilabel(dg,'Text','TDoA COVARIANCE R (m^2)','FontWeight','bold');
        d2.Layout.Row=3;
        app.RTable=uitable(dg,'Data',nan(3,3), ...
            'ColumnName',{'RX2-RX1','RX3-RX1','RX4-RX1'}, ...
            'ColumnEditable',[false false false]);
        app.RTable.Layout.Row=4;
        app.logBox=uitextarea(dg,'Editable','off','Value',app.logLines,'FontSize',10);
        app.logBox.Layout.Row=5;
        mg=uigridlayout(tbMC,[2 1]);
        mg.RowHeight={'2x','1x'};
        mg.Padding=[4 4 4 4];
        app.mcAx=uiaxes(mg);
        app.mcTable=uitable(mg,'Data',nan(3,6), ...
            'ColumnName',{'Pt (dBm)','N OK','N failed','RMSE (m)','CRLB RMS','SNR (dB)'}, ...
            'ColumnEditable',false(1,6));
    end

    function addSlider(parent,row,caption,key,limits,format,isInteger)
        labelAt(parent,row,caption);
        val=setting(key);
        sl=uislider(parent,'Limits',limits,'Value',val,'MajorTicks',[]);
        setSpan(sl,row,2);
        number=uilabel(parent,'HorizontalAlignment','right', ...
            'Text',sprintf(format,val),'FontWeight','bold');
        setSpan(number,row,3);
        sl.ValueChangingFcn=@(~,event)previewSlider(number,event.Value,format,isInteger);
        sl.ValueChangedFcn=@(~,event)commitSlider(key,event.Value,number,format,isInteger);
        if ~strcmp(key,'playbackDelay')
            lockable(sl);
        end
    end

    function v=setting(key)
        switch key
            case 'vx', v=app.cfg.velocity(1);
            case 'vy', v=app.cfg.velocity(2);
            case 'windowLength', v=app.cfg.fusion.windowLength;
            case 'windowDecay', v=app.cfg.fusion.windowDecay;
            case 'playbackDelay', v=app.playbackDelay;
            otherwise, v=app.cfg.(key);
        end
    end

    function previewSlider(label,val,fmt,isInteger)
        if isInteger, val=round(val); end
        label.Text=sprintf(fmt,val);
    end

    function commitSlider(key,val,label,fmt,isInteger)
        if isInteger,val=round(val);end
        label.Text=sprintf(fmt,val);
        switch key
            case 'vx', app.cfg.velocity(1)=val;
            case 'vy', app.cfg.velocity(2)=val;
            case 'windowLength', app.cfg.fusion.windowLength=val;
            case 'windowDecay', app.cfg.fusion.windowDecay=val;
            case 'playbackDelay', app.playbackDelay=val;return
            otherwise, app.cfg.(key)=val;
        end
        if strcmp(key,'zpFactor')
            app.cfg.zpFactor=max(1,round(val));
        end
        if strcmp(key,'Nmc'), return; end
        invalidateResults(sprintf('Updated %s = %g.',key,val));
    end

    function titleRow(g,row,message)
        x=uilabel(g,'Text',message,'FontWeight','bold', ...
            'FontSize',12,'FontColor',[0.20 0.38 0.59]);
        setSpan(x,row,[1 3]);
    end
    function labelAt(g,row,message)
        x=uilabel(g,'Text',message,'FontSize',11);
        setSpan(x,row,1);
    end
    function setSpan(h,row,col)
        h.Layout.Row=row;
        h.Layout.Column=col;
    end
    function lockable(h)
        app.lockables{end+1}=h;
    end

    function modeChanged(src,~)
        app.cfg.experimentMode=char(src.Value);
        if strcmpi(app.cfg.experimentMode,'moving') && ~strcmpi(app.cfg.fusionOutput,'kalman')
            appendLog('Moving TX: Block 5 automatically uses Kalman tracking. Static fusion is suppressed.');
        end
        invalidateResults(['Mode set to ' app.cfg.experimentMode '.']);
    end
    function fusionChanged(src,~)
        app.cfg.fusionOutput=char(src.Value);
        invalidateResults(['Fusion output set to ' app.cfg.fusionOutput '.']);
    end
    function bandChanged(src,~)
        cbw=char(src.Value);
        app.cfg.cbw=cbw;
        app.cfg.B=str2double(cbw(4:end))*1e6;
        app.cfg.fs=app.cfg.B;   % non-HT WLAN sample rate, no oversampling
        app.cfg.closeSep=1.5/app.cfg.fs;
        invalidateResults(sprintf('Wi-Fi bandwidth = %g MHz.',app.cfg.B/1e6));
    end
    function pathChanged(src,~)
        app.cfg.firstPathMethod=char(src.Value);
        invalidateResults(['First-path method: ' app.cfg.firstPathMethod '.']);
    end
    function hyperChanged(src,~)
        app.showHyperbolas=logical(src.Value);
        drawMap();
    end
    function txEditChanged(~,~)
        if app.running, return; end
        proposal=[app.txX.Value;app.txY.Value];
        if ~validPosition(proposal,0)
            app.txX.Value=app.cfg.P0(1);app.txY.Value=app.cfg.P0(2);
            appendLog('TX coordinate rejected: TX must remain at least 0.25 m from every RX.');
            return
        end
        app.cfg.P0=proposal;
        invalidateResults('Transmitter moved using numeric fields.');
    end
    function rxEdited(~,event)
        if app.running, return; end
        row=event.Indices(1);
        candidate=app.rxTable.Data;
        if ~all(isfinite(candidate(:))) || ~validReceiverLayout(candidate) || ...
                ~validPosition(app.cfg.P0,0,candidate)
            app.rxTable.Data=app.cfg.Rx;
            appendLog(sprintf('RX%d edit rejected: colliding antennas or invalid coordinates.',row));
            return
        end
        app.cfg.Rx=candidate;
        app.cfg.Pinit=mean(app.cfg.Rx,1).';
        invalidateResults(sprintf('Updated receiver %d coordinates.',row));
    end
    function addWallClicked(~,~)
        if app.running, return; end
        app.addingWall=true;
        app.wallFirst=[];
        app.sceneHint.Text='ADDING WALL: click first endpoint on the map.';
        app.status.Text='MAP EDIT  |  Wall point 1/2';
        appendLog('Add wall mode: click two empty locations in the map.');
    end
    function removeWallClicked(~,~)
        if isempty(app.cfg.walls), return;end
        app.cfg.walls(end,:)=[];
        invalidateResults('Last wall removed.');
    end
    function clearWallsClicked(~,~)
        app.cfg.walls=zeros(0,4);
        app.addingWall=false;
        app.wallFirst=[];
        invalidateResults('All walls cleared.');
    end
    function restoreSceneClicked(~,~)
        app.cfg.Rx=app.startConfig.Rx;
        app.cfg.P0=app.startConfig.P0;
        app.cfg.Pinit=app.startConfig.Pinit;
        app.cfg.walls=app.startConfig.walls;
        app.addingWall=false;
        app.wallFirst=[];
        app.sceneBounds=initialBounds(app.cfg);
        app.rxTable.Data=app.cfg.Rx;
        app.txX.Value=app.cfg.P0(1);
        app.txY.Value=app.cfg.P0(2);
        invalidateResults('Restored default transmitter, receivers, and walls.');
    end
    function fitClicked(~,~)
        app.sceneBounds=initialBounds(app.cfg);
        drawMap();
    end
    function zoomInClicked(~,~)
        zoomBy(0.8);
    end
    function zoomOutClicked(~,~)
        zoomBy(1.25);
    end
    function zoomBy(factor)
        b=app.sceneBounds;
        center=[mean(b(1:2)) mean(b(3:4))];
        half=[diff(b(1:2)) diff(b(3:4))]*factor/2;
        app.sceneBounds=[center(1)-half(1) center(1)+half(1) ...
                         center(2)-half(2) center(2)+half(2)];
        drawMap();
    end

    function mapClick(~,~)
        if app.running || ~app.addingWall, return; end
        xy=pointOnMap();
        if isempty(xy), return;end
        if isempty(app.wallFirst)
            app.wallFirst=xy;
            app.sceneHint.Text='ADDING WALL: click second endpoint on the map.';
            app.status.Text='MAP EDIT  |  Wall point 2/2';
            drawMap();
        else
            if norm(xy-app.wallFirst)<0.20
                app.sceneHint.Text='Wall too short. Choose another endpoint.';
                return
            end
            app.cfg.walls(end+1,:)=[app.wallFirst xy];
            app.addingWall=false;
            app.wallFirst=[];
            app.sceneHint.Text='Wall added. Drag its endpoint or center to edit.';
            invalidateResults('Wall added; Block 1 will compute reflection paths.');
        end
    end

    function beginDrag(which,index)
        if app.running || app.addingWall,return;end
        xy=pointOnMap();
        if isempty(xy),return;end
        d=struct('kind',which,'index',index,'start',xy, ...
            'P0',app.cfg.P0,'Rx',app.cfg.Rx,'walls',app.cfg.walls, ...
            'changed',false);
        if strcmp(which,'wall')
            w=app.cfg.walls(index,:);
            a=w(1:2);b=w(3:4);
            threshold=0.085*min(diff(app.sceneBounds(1:2)),diff(app.sceneBounds(3:4)));
            if norm(xy-a)<min(norm(xy-b),threshold)
                d.kind='wallA';
            elseif norm(xy-b)<threshold
                d.kind='wallB';
            else
                d.kind='wallMove';
            end
        end
        app.drag=d;
        app.status.Text=['DRAGGING  |  ' upper(d.kind)];
    end
    function mouseMove(~,~)
        if isempty(app.drag) || app.running, return;end
        xy=pointOnMap();
        if isempty(xy),return;end
        d=app.drag;
        switch d.kind
            case 'tx'
                if validPosition(xy(:),0)
                    app.cfg.P0=xy(:);
                end
            case 'rx'
                r=d.index;
                proposed=app.cfg.Rx;
                proposed(r,:)=xy;
                if validReceiverLayout(proposed) && validPosition(app.cfg.P0,0,proposed)
                    app.cfg.Rx=proposed;
                end
            case 'wallA'
                app.cfg.walls(d.index,1:2)=xy;
            case 'wallB'
                app.cfg.walls(d.index,3:4)=xy;
            case 'wallMove'
                shift=xy-d.start;
                app.cfg.walls(d.index,:)=d.walls(d.index,:)+[shift shift];
        end
        if ~isequal(app.cfg.P0,d.P0) || ~isequal(app.cfg.Rx,d.Rx) || ...
                ~isequal(app.cfg.walls,d.walls)
            app.drag.changed=true;
        end
        drawMap();
    end
    function mouseUp(~,~)
        if isempty(app.drag),return;end
        d=app.drag;
        app.drag=[];
        if any(strcmp(d.kind,{'wallA','wallB','wallMove'}))
            w=app.cfg.walls(d.index,:);
            if norm(w(3:4)-w(1:2))<0.2
                app.cfg.walls=d.walls;
                appendLog('Wall edit cancelled: length must exceed 0.2 m.');
                drawMap();
                return
            end
        end
        if d.changed
            app.rxTable.Data=app.cfg.Rx;
            app.txX.Value=app.cfg.P0(1);
            app.txY.Value=app.cfg.P0(2);
            app.cfg.Pinit=mean(app.cfg.Rx,1).';
            invalidateResults('Scene geometry changed by dragging.');
        else
            app.status.Text='READY  |  Scene editable';
        end
    end
    function xy=pointOnMap()
        xy=[];
        if ~isvalid(fig) || ~isvalid(app.mapAx),return;end
        p=app.mapAx.CurrentPoint;
        if isempty(p) || any(~isfinite(p(1,1:2))),return;end
        b=app.sceneBounds;
        xy=[min(max(p(1,1),b(1)),b(2)), ...
            min(max(p(1,2),b(3)),b(4))];
    end
    function tf=validPosition(p,~,rx)
        if nargin<3,rx=app.cfg.Rx;end
        p=p(:).';
        tf=numel(p)==2 && all(isfinite(p)) && ...
            all(hypot(rx(:,1)-p(1),rx(:,2)-p(2)) >= 0.25);
    end
    function tf=validReceiverLayout(Rx)
        tf=isequal(size(Rx),[4 2]) && all(isfinite(Rx(:)));
        if ~tf,return;end
        for i=1:4
            for j=i+1:4
                if norm(Rx(i,:)-Rx(j,:))<0.25,tf=false;return;end
            end
        end
    end

    function invalidateResults(reason)
        app.state=[];app.Ppred=[];app.k=0;
        app.last=[];app.mc=[];
        app.history=blankHistory();
        app.addingWall=false;
        app.wallFirst=[];
        app.status.Text='READY  |  Settings changed';
        app.sceneHint.Text='Drag positions or click Add wall to change geometry.';
        resetPlots();
        drawMap();
        appendLog([reason ' History and filter memory reset.']);
    end
    function resetSession()
        app.k=0;app.state=[];app.Ppred=[];
        app.last=[];app.history=blankHistory();
        app.status.Text='READY  |  New sequence';
        rng(app.cfg.seed,'twister');
        resetPlots();
        drawMap();
    end
    function resetClicked(~,~)
        if app.running,return;end
        resetSession();
        appendLog('Tracking / packet history reset. Scene settings retained.');
    end
    function closeApp(~,~)
        app.stopRequested=true;
        if isvalid(fig),delete(fig);end
    end
    function showHelp(~,~)
        msg=sprintf([ ...
            '1. Drag the gold transmitter and blue receiver markers.\n' ...
            '2. To add a wall: Scene Editor > Add wall, then click two map points.\n' ...
            '3. Drag a purple wall near an endpoint to reshape, or at its center to move.\n' ...
            '4. Use sliders for power, noise, bandwidth, motion and filtering.\n' ...
            '5. STEP runs one full packet; FULL RUN animates multiple packets.\n' ...
            '6. The tabs show received samples, CSI, CIR, TDoA, CRLB, and diagnostics.\n' ...
            '7. Monte Carlo runs the original full pipeline per trial. STOP works between trials.\n\n' ...
            'Important: static/window fusion is not mathematically valid for a moving TX.\n' ...
            'The original Block 1 walls reflect paths but do not attenuate direct paths.']);
        uialert(fig,msg,'GUI help','Icon','info');
    end

    function drawMap()
        if ~isvalid(fig),return;end
        ax=app.mapAx;
        cla(ax);
        hold(ax,'on');
        grid(ax,'on');axis(ax,'equal');
        xlim(ax,app.sceneBounds(1:2));
        ylim(ax,app.sceneBounds(3:4));
        ax.Color=[0.995 0.997 1];
        ax.XColor=[0.25 0.33 0.43];ax.YColor=[0.25 0.33 0.43];
        tx=app.cfg.P0(:);
        if ~isempty(app.last) && isfield(app.last.truth,'P0')
            tx=app.last.truth.P0(:);
        end
        if app.showHyperbolas && ~isempty(app.last)
            xg=linspace(app.sceneBounds(1),app.sceneBounds(2),130);
            yg=linspace(app.sceneBounds(3),app.sceneBounds(4),130);
            [X,Y]=meshgrid(xg,yg);
            r0=app.cfg.Rx(app.cfg.refIdx,:);
            D0=hypot(X-r0(1),Y-r0(2));
            others=app.cfg.others;
            hcolors=[0.30 0.61 0.92;0.60 0.41 0.80;0.20 0.65 0.48];
            for j=1:numel(others)
                ri=app.cfg.Rx(others(j),:);
                Z=hypot(X-ri(1),Y-ri(2))-D0;
                z0=app.last.deltad(j);
                if isfinite(z0) && min(Z(:))<=z0 && max(Z(:))>=z0
                    [~, contourObj]=contour(ax,X,Y,Z,[z0 z0],'LineWidth',1.0, ...
                        'LineStyle',':','LineColor',hcolors(j,:));
                    contourObj.HitTest='off';
                end
            end
        end
        % The direct path and estimated reflection paths are visual overlays
        % only. All RF computation is performed by the supplied Block 1.
        for ri=1:size(app.cfg.Rx,1)
            rx=app.cfg.Rx(ri,:);
            h=plot(ax,[tx(1) rx(1)],[tx(2) rx(2)],'--', ...
                'Color',[0.73 0.77 0.84],'LineWidth',1.0);
            h.HitTest='off';
            if ~isempty(app.last)
                truth=app.last.truth;
                if isfield(truth,'hasBounce') && truth.hasBounce(ri) && ...
                        all(isfinite(truth.bouncePoint(:,ri)))
                    b=truth.bouncePoint(:,ri);
                    h=plot(ax,[tx(1) b(1) rx(1)],[tx(2) b(2) rx(2)],':', ...
                        'Color',app.palette.purple,'LineWidth',1.7);
                    h.HitTest='off';
                end
            end
        end
        % Draw editable walls before antenna markers to make markers clickable.
        for wi=1:size(app.cfg.walls,1)
            w=app.cfg.walls(wi,:);
            plot(ax,w([1 3]),w([2 4]),'-', ...
                'Color',app.palette.purple,'LineWidth',5, ...
                'ButtonDownFcn',@(~,~)beginDrag('wall',wi));
            h=plot(ax,w([1 3]),w([2 4]),'s', ...
                'MarkerSize',6,'MarkerFaceColor',[0.8 0.65 0.9], ...
                'Color',app.palette.purple, ...
                'ButtonDownFcn',@(~,~)beginDrag('wall',wi));
        end
        if ~isempty(app.wallFirst)
            h=plot(ax,app.wallFirst(1),app.wallFirst(2),'s', ...
                'MarkerSize',10,'LineWidth',2,'Color',app.palette.purple);
            h.HitTest='off';
        end
        if ~isempty(app.history.time)
            plot(ax,app.history.truePosition(1,:),app.history.truePosition(2,:),'-', ...
                'Color',[0.80 0.56 0.18],'LineWidth',1.4,'HitTest','off');
            plot(ax,app.history.trackPosition(1,:),app.history.trackPosition(2,:),'-', ...
                'Color',app.palette.teal,'LineWidth',1.8,'HitTest','off');
        end
        if ~isempty(app.last)
            p=app.last;
            plot(ax,p.Phat(1),p.Phat(2),'x','Color',app.palette.red, ...
                'MarkerSize',13,'LineWidth',2.2,'HitTest','off');
            plot(ax,p.Ptrk(1),p.Ptrk(2),'o','Color',app.palette.teal, ...
                'MarkerFaceColor',[0.74 0.93 0.86], ...
                'MarkerSize',9,'LineWidth',1.5,'HitTest','off');
            plotEllipse(ax,p.Phat,p.Pcov,app.palette.red);
        end
        for ri=1:size(app.cfg.Rx,1)
            rx=app.cfg.Rx(ri,:);
            plot(ax,rx(1),rx(2),'^','MarkerFaceColor',app.palette.blue, ...
                'Color',[0.04 0.23 0.48],'MarkerSize',12,'LineWidth',1.1, ...
                'ButtonDownFcn',@(~,~)beginDrag('rx',ri));
            h=text(ax,rx(1)+0.2,rx(2)+0.30,sprintf('RX%d',ri), ...
                'FontSize',10,'FontWeight','bold','Color',app.palette.blue);
            h.HitTest='off';
        end
        plot(ax,tx(1),tx(2),'p','MarkerFaceColor',app.palette.gold, ...
            'Color',[0.63 0.38 0.05],'MarkerSize',16,'LineWidth',1.1, ...
            'ButtonDownFcn',@(~,~)beginDrag('tx',0));
        h=text(ax,tx(1)+0.25,tx(2)+0.30,'Wi-Fi TX', ...
            'FontSize',11,'FontWeight','bold','Color',[0.65 0.41 0.07]);
        h.HitTest='off';
        xlabel(ax,'X position (m)');ylabel(ax,'Y position (m)');
        title(ax,'Drag gold TX / blue RX / purple walls   |   dotted curves = measured TDoAs');
        hold(ax,'off');
    end

    function plotEllipse(ax,p,C,color)
        if ~isequal(size(C),[2 2]) || any(~isfinite(C(:))),return;end
        [V,D]=eig((C+C')/2);
        lam=diag(D);
        if any(lam<0),return;end
        theta=linspace(0,2*pi,150);
        ellipse=V*diag(sqrt(lam*(-2*log(0.05))))*[cos(theta);sin(theta)] ...
            +p(:);
        h=plot(ax,ellipse(1,:),ellipse(2,:),'-','Color',color,'LineWidth',1.3);
        h.HitTest='off';
    end
    function drawHistory()
        ax=app.errorAx;
        cla(ax);grid(ax,'on');hold(ax,'on');
        if ~isempty(app.history.time)
            plot(ax,app.history.time,app.history.rawError,'o-', ...
                'Color',app.palette.red,'LineWidth',1.3,'MarkerSize',4);
            plot(ax,app.history.time,app.history.trackError,'s-', ...
                'Color',app.palette.teal,'LineWidth',1.3,'MarkerSize',4);
            legend(ax,{'Raw error','Tracked error'},'Location','best');
        end
        xlabel(ax,'Time (s)');ylabel(ax,'Euclidean position error (m)');
        title(ax,'Raw vs tracked error (actual Block 4 and Block 5 outputs)');
        hold(ax,'off');
    end
    function drawSignals()
        if isempty(app.last),return;end
        p=app.last;
        ax=app.waveAx;cla(ax);
        N=size(p.Y,1);
        ix=unique(round(linspace(1,N,min(N,2200))));
        plot(ax,1e6*(ix-1)/app.cfg.fs,abs(p.Y(ix,:)),'LineWidth',0.95);
        grid(ax,'on');xlabel(ax,'Time (microseconds)');ylabel(ax,'|Y|');
        title(ax,'Block 1: received Wi-Fi samples (display decimated)');
        ax=app.csiAx;cla(ax);
        plot(ax,1:size(p.Hhat,1),abs(p.Hhat),'LineWidth',1.0);
        grid(ax,'on');xlabel(ax,'Allocated subcarrier');ylabel(ax,'|CSI|');
        title(ax,'Block 2: per-RX L-LTF channel magnitude');
        ax=app.cirAx;cla(ax);
        C=fftshift(p.info3.cir,1);
        N=size(C,1);
        tau=((0:N-1)'-floor(N/2))/(app.cfg.fs*app.cfg.zpFactor)*1e9;
        plot(ax,tau,abs(C),'LineWidth',1.0);
        grid(ax,'on');xlabel(ax,'Relative delay (ns)');ylabel(ax,'|CIR|');
        title(ax,'Block 3: zero-padded CIR (relative timing)');
    end
    function drawLocalization()
        if isempty(app.last),return;end
        p=app.last;
        ax=app.tdoaAx;cla(ax);
        bs=bar(ax,1:numel(p.deltad),[p.truth.deltad(:),p.deltad(:)]);
        bs(1).FaceColor=[0.77 0.78 0.82];
        bs(2).FaceColor=app.palette.blue;
        grid(ax,'on');xlabel(ax,'RX pair vs reference');ylabel(ax,'Delta range (m)');
        title(ax,'Block 3: true vs estimated TDoA');
        legend(ax,{'Ground truth','Estimated'},'Location','best');
        ax=app.locErrorAx;cla(ax);
        if ~isempty(app.history.time)
            plot(ax,app.history.time,app.history.rawError,'o-', ...
                'Color',app.palette.red,'LineWidth',1.2);hold(ax,'on');
            plot(ax,app.history.time,app.history.trackError,'s-', ...
                'Color',app.palette.teal,'LineWidth',1.2);hold(ax,'off');
        end
        grid(ax,'on');xlabel(ax,'Time (s)');ylabel(ax,'Error (m)');
        title(ax,'Raw and tracked localization error');
        ax=app.covAx;cla(ax);
        imagesc(ax,p.Pcov);axis(ax,'image');
        ax.XTick=1:2;ax.YTick=1:2;
        ax.XTickLabel={'X','Y'};ax.YTickLabel={'X','Y'};
        colorbar(ax);
        title(ax,'Block 4 local CRLB covariance (m^2)');
    end
    function drawDiagnostics()
        if ~isempty(app.last)
            p=app.last;
            app.rxDiagTable.Data=[(1:size(app.cfg.Rx,1)).', ...
                p.truth.d(:),1e9*p.info3.tauHat(:),p.info3.snrFirst_dB(:)];
            app.RTable.Data=p.R;
            names=arrayfun(@(i)sprintf('RX%d-RX%d',i,app.cfg.refIdx), ...
                app.cfg.others(:).','UniformOutput',false);
            app.RTable.ColumnName=names;
        end
        app.logBox.Value=app.logLines(:);
    end
    function drawMC()
        if isempty(app.mc),return;end
        mc=app.mc;
        ax=app.mcAx;cla(ax);
        good=isfinite(mc.meanSNR_dB) & isfinite(mc.rmse);
        if any(good)
            plot(ax,mc.meanSNR_dB(good),mc.rmse(good),'-o', ...
                'Color',app.palette.red,'LineWidth',1.7);hold(ax,'on');
            plot(ax,mc.meanSNR_dB(good),mc.crlbRMS(good),'--s', ...
                'Color',app.palette.blue,'LineWidth',1.3);hold(ax,'off');
            legend(ax,{'Measured RMSE','Local CRLB RMS'},'Location','best');
        end
        grid(ax,'on');xlabel(ax,'Mean RX1 SNR (dB)');ylabel(ax,'Position RMSE (m)');
        title(ax,sprintf('Monte Carlo (%d trial slots per power)',mc.Ntrials));
        app.mcTable.Data=[mc.power_dBm,mc.nSuccess,mc.nFailed, ...
            mc.rmse,mc.crlbRMS,mc.meanSNR_dB];
    end
    function updateSummary()
        if isempty(app.last)
            app.summary.Value={'No processed packets yet.', ...
                '1) Edit the scene / RF settings', ...
                '2) Press STEP or FULL RUN'};
            return
        end
        p=app.last;
        rmseRaw=sqrt(mean(app.history.rawError.^2));
        rmseTrack=sqrt(mean(app.history.trackError.^2));
        report={...
            sprintf('PACKET %d / %d   (%s)',app.k,app.cfg.Npackets,app.cfg.experimentMode), ...
            sprintf('True TX    [%7.3f, %7.3f] m',p.truth.P0), ...
            sprintf('Raw WNLS   [%7.3f, %7.3f] m',p.Phat), ...
            sprintf('Tracked    [%7.3f, %7.3f] m',p.Ptrk), ...
            sprintf('Error: RAW %.3f m | TRACK %.3f m',p.rawError,p.trackError), ...
            sprintf('RMSE:  RAW %.3f m | TRACK %.3f m',rmseRaw,rmseTrack), ...
            sprintf('CRLB sqrt(trace): %.3f m',sqrt(trace(p.Pcov)))};
        if strcmpi(app.cfg.experimentMode,'stationary') && ~isempty(p.fusion.cumulative)
            report{end+1}=sprintf('Fusion ready: cum=%d window=%d', ...
                p.fusion.cumulative.ready,p.fusion.window.ready);
        end
        app.summary.Value=report;
    end
    function renderAll()
        if ~isvalid(fig),return;end
        drawMap();drawHistory();drawSignals();drawLocalization();
        drawDiagnostics();updateSummary();
    end
    function resetPlots()
        cla(app.mapAx);cla(app.errorAx);
        cla(app.waveAx);cla(app.csiAx);cla(app.cirAx);
        cla(app.tdoaAx);cla(app.locErrorAx);cla(app.covAx);
        cla(app.mcAx);
        title(app.waveAx,'Block 1: received Wi-Fi signal');
        title(app.csiAx,'Block 2: channel estimate / CSI');
        title(app.cirAx,'Block 3: channel impulse response');
        title(app.tdoaAx,'TDoA: actual vs estimated');
        title(app.locErrorAx,'Position error vs packet');
        title(app.covAx,'CRLB covariance');
        title(app.mcAx,'Run Monte Carlo to see RMSE vs SNR');
        app.rxDiagTable.Data=nan(4,4);app.RTable.Data=nan(3,3);
        app.mcTable.Data=nan(3,6);
        updateSummary();drawHistory();
    end
    function appendLog(message)
        timestamp=datestr(now,'HH:MM:SS');
        app.logLines{end+1}=sprintf('%s  %s',timestamp,message);
        if numel(app.logLines)>180
            app.logLines=app.logLines(end-179:end);
        end
        if isfield(app,'logBox') && isvalid(app.logBox)
            app.logBox.Value=app.logLines(:);
        end
    end

    function setBusy(busy)
        app.running=busy;
        for ii=1:numel(app.lockables)
            h=app.lockables{ii};
            if ~isvalid(h),continue;end
            if busy,h.Enable='off';else,h.Enable='on';end
        end
        if busy
            app.btnStop.Enable='on';
            app.btnPause.Enable='on';
        else
            app.btnStop.Enable='off';
            app.btnPause.Enable='off';
            app.paused=false;
        end
    end
    function pauseClicked(~,~)
        if ~app.running,return;end
        app.paused=~app.paused;
        if app.paused
            app.status.Text='PAUSED  |  press PAUSE / RESUME';
        else
            app.status.Text='RUNNING  |  resumed';
        end
    end
    function waitIfPaused()
        while app.paused && ~app.stopRequested && isvalid(fig)
            drawnow;pause(0.06);
        end
    end
    function stopClicked(~,~)
        app.stopRequested=true;
        if app.running
            app.status.Text='STOP REQUESTED  |  finishing current packet';
            appendLog('Stop requested. Current packet/trial will finish first.');
        end
    end
    function stepClicked(~,~)
        if app.running,return;end
        if app.k==0,rng(app.cfg.seed,'twister');end
        app.stopRequested=false;
        setBusy(true);
        try
            executeFrame();
            app.status.Text=sprintf('FRAME %d COMPLETE  |  error %.3f m', ...
                app.k,app.last.trackError);
        catch ME
            reportFailure(ME);
        end
        if isvalid(fig),setBusy(false);end
    end
    function runClicked(~,~)
        if app.running,return;end
        resetSession();
        app.stopRequested=false;
        app.paused=false;
        setBusy(true);
        appendLog(sprintf('Starting %d %s packets through real Blocks 1-5.', ...
            app.cfg.Npackets,app.cfg.experimentMode));
        for frame=1:app.cfg.Npackets
            if app.stopRequested || ~isvalid(fig),break;end
            try
                executeFrame();
                app.status.Text=sprintf('RUNNING  |  %d/%d  |  last error %.3f m', ...
                    app.k,app.cfg.Npackets,app.last.trackError);
            catch ME
                reportFailure(ME);
                app.stopRequested=true;
                break;
            end
            drawnow;
            waitIfPaused();
            if app.playbackDelay>0,pause(app.playbackDelay);end
        end
        if ~isvalid(fig),return;end
        if app.stopRequested
            appendLog(sprintf('Stopped after %d successful packets.',app.k));
            app.status.Text=sprintf('STOPPED  |  %d packets retained',app.k);
        else
            app.status.Text=sprintf('COMPLETE  |  %d packets',app.k);
            if app.k>0
                appendLog(sprintf('Complete: raw RMSE %.3f m, tracked RMSE %.3f m.', ...
                    sqrt(mean(app.history.rawError.^2)), ...
                    sqrt(mean(app.history.trackError.^2))));
            end
        end
        setBusy(false);
    end
    function executeFrame()
        k=app.k+1;
        t=(k-1)*app.cfg.dt;
        frameCfg=app.cfg;
        if strcmpi(app.cfg.experimentMode,'moving')
            frameCfg.P0=app.cfg.P0 + app.cfg.velocity*t + ...
                app.cfg.motionAmplitude.*sin(2*pi*app.cfg.motionFrequency*t);
        end
        if any(hypot(frameCfg.Rx(:,1)-frameCfg.P0(1), ...
                     frameCfg.Rx(:,2)-frameCfg.P0(2))<0.25)
            error('capstoneGUI:TXReceiverCollision', ...
                'Transmitter reached within 0.25 m of a receiver in this frame.');
        end
        [p,newState,nextPred]=capstoneGuiPacket(frameCfg,app.state,app.Ppred,k);
        % Mutate app state only AFTER a complete five-block packet succeeds.
        app.state=newState;
        app.Ppred=nextPred;
        app.last=p;
        app.k=k;
        h=app.history;
        h.time(end+1)=t;
        h.truePosition(:,end+1)=p.truth.P0;
        h.rawPosition(:,end+1)=p.Phat;
        h.trackPosition(:,end+1)=p.Ptrk;
        h.rawError(end+1)=p.rawError;
        h.trackError(end+1)=p.trackError;
        h.localBound(end+1)=sqrt(max(trace(p.Pcov),0));
        h.deltad(:,end+1)=p.deltad;
        app.history=h;
        renderAll();
        diagnostic=sprintf('Packet %d: TDoA=[%s] m, raw error=%.3f, track error=%.3f.', ...
            k,strtrim(sprintf('%.2f ',p.deltad)),p.rawError,p.trackError);
        appendLog(diagnostic);
        if isfield(p.truth,'blocked') && any(p.truth.blocked)
            appendLog('MODEL NOTE: wall intersects LoS, but supplied Block 1 does not attenuate the direct path.');
        end
        if ~p.info4.converged || ~p.info4.chi2Pass || p.info4.ambiguous
            appendLog(sprintf('Block 4 warnings: converged=%d chi2Pass=%d ambiguous=%d.', ...
                p.info4.converged,p.info4.chi2Pass,p.info4.ambiguous));
        end
        if strcmpi(app.cfg.experimentMode,'stationary')
            if ~isempty(p.fusion.cumulative)
                appendLog(sprintf('Fusion status: cumulative=%s (ready=%d), window=%s (ready=%d).', ...
                    p.fusion.cumulative.status,p.fusion.cumulative.ready, ...
                    p.fusion.window.status,p.fusion.window.ready));
            end
            if ~isempty(p.fusion.cumulative) && p.fusion.cumulative.modelMismatch
                appendLog('Cumulative TDoA consistency check: MODEL MISMATCH.');
            end
            if ~isempty(p.fusion.window) && p.fusion.window.modelMismatch
                appendLog('Window fusion consistency check: MODEL MISMATCH.');
            end
        end
    end
    function reportFailure(ME)
        message=sprintf('%s: %s',ME.identifier,ME.message);
        app.status.Text='ERROR  |  open Diagnostics';
        appendLog(['BLOCK / GUI ERROR: ' message]);
        if isvalid(fig)
            uialert(fig,message,'Packet processing failed','Icon','error');
        end
    end
    function mcClicked(~,~)
        if app.running,return;end
        app.stopRequested=false;
        app.paused=false;
        setBusy(true);
        powers=app.cfg.mcPower_dBm(:);
        n=app.cfg.Nmc;
        mc=struct('power_dBm',powers,'nSuccess',zeros(numel(powers),1), ...
            'nFailed',zeros(numel(powers),1),'rmse',nan(numel(powers),1), ...
            'crlbRMS',nan(numel(powers),1),'meanSNR_dB',nan(numel(powers),1), ...
            'Ntrials',n,'failures',{{}});
        oldRng=rng;
        app.status.Text=sprintf('MONTE CARLO  |  %d x %d trials',numel(powers),n);
        appendLog(sprintf('Monte Carlo: %d power settings x %d trials. No ideal TDoAs.', ...
            numel(powers),n));
        for j=1:numel(powers)
            errors=nan(n,1);snrs=nan(n,1);bounds=nan(n,1);
            for trialIdx=1:n
                if app.stopRequested || ~isvalid(fig),break;end
                trialCfg=app.cfg;
                trialCfg.Pt_dBm=powers(j);
                trialCfg.experimentMode='stationary';
                trialCfg.Npackets=1;
                trialCfg.enablePlots=false;
                trialCfg.printProgress=false;
                trialCfg.runMonteCarlo=false;
                trialCfg.seed=app.cfg.seed+10000*j+trialIdx;
                try
                    % Existing end-to-end runner, including all five actual blocks.
                    result=runCapstoneExperiment(trialCfg);
                    errors(trialIdx)=result.rawError(1);
                    snrs(trialIdx)=result.truth{1}.SNR_dB(trialCfg.refIdx);
                    bounds(trialIdx)=result.crlbTrace(1);
                    mc.nSuccess(j)=mc.nSuccess(j)+1;
                catch ME
                    mc.nFailed(j)=mc.nFailed(j)+1;
                    mc.failures{end+1}=sprintf('Pt=%g, trial=%d: %s: %s', ...
                        powers(j),trialIdx,ME.identifier,ME.message); %#ok<AGROW>
                    appendLog(['MC failure: ' mc.failures{end}]);
                end
                app.status.Text=sprintf('MONTE CARLO  |  power %d/%d  trial %d/%d', ...
                    j,numel(powers),trialIdx,n);
                drawnow;
                waitIfPaused();
            end
            valid=isfinite(errors);
            if any(valid)
                mc.rmse(j)=sqrt(mean(errors(valid).^2));
                mc.meanSNR_dB(j)=mean(snrs(valid));
                mc.crlbRMS(j)=sqrt(mean(bounds(valid)));
            end
            if ~isvalid(fig)
                rng(oldRng);
                return
            end
            app.mc=mc;
            drawMC();
            drawnow;
            appendLog(sprintf('MC Pt=%.1f dBm: %d/%d passed, raw RMSE=%.3f m.', ...
                powers(j),mc.nSuccess(j),mc.nSuccess(j)+mc.nFailed(j),mc.rmse(j)));
            if app.stopRequested,break;end
        end
        rng(oldRng);
        if ~isvalid(fig),return;end
        if app.stopRequested
            app.status.Text='MONTE CARLO STOPPED  |  partial results';
        else
            app.status.Text='MONTE CARLO COMPLETE';
        end
        % Select the MC tab by title, without relying on reversed child order.
        tabs=app.resultTabs.Children;
        for jj=1:numel(tabs)
            if strcmp(tabs(jj).Title,'Monte Carlo')
                app.resultTabs.SelectedTab=tabs(jj);break;
            end
        end
        setBusy(false);
    end

    function saveClicked(~,~)
        [name,path]=uiputfile('*.mat','Save complete GUI capstone session','capstone_session.mat');
        if isequal(name,0),return;end
        session=struct('cfg',app.cfg,'history',app.history,'last',app.last, ...
            'state',app.state,'mc',app.mc,'savedAt',datetime('now'));
        save(fullfile(path,name),'session','-v7.3');
        appendLog(['Session saved: ' fullfile(path,name)]);
    end
    function csvClicked(~,~)
        if isempty(app.history.time)
            uialert(fig,'Run one or more packets before exporting.','Nothing to export');return
        end
        [name,path]=uiputfile('*.csv','Save packet-by-packet metrics','capstone_history.csv');
        if isequal(name,0),return;end
        h=app.history;
        T=table((1:app.k)',h.time(:),h.truePosition(1,:)',h.truePosition(2,:)', ...
            h.rawPosition(1,:)',h.rawPosition(2,:)',h.trackPosition(1,:)', ...
            h.trackPosition(2,:)',h.rawError(:),h.trackError(:),h.localBound(:), ...
            'VariableNames',{'Packet','Time_s','True_X_m','True_Y_m', ...
            'Raw_X_m','Raw_Y_m','Tracked_X_m','Tracked_Y_m', ...
            'RawError_m','TrackedError_m','CRLB_sqrtTrace_m'});
        writetable(T,fullfile(path,name));
        appendLog(['CSV exported: ' fullfile(path,name)]);
    end
    function imageClicked(~,~)
        [name,path]=uiputfile('*.png','Export scene map as PNG','capstone_scene.png');
        if isequal(name,0),return;end
        exportgraphics(app.mapAx,fullfile(path,name),'Resolution',180);
        appendLog(['Scene exported: ' fullfile(path,name)]);
    end
end

function b=initialBounds(cfg)
% Constrain drag to a generous map extent and keep scale stable while moving.
points=[cfg.Rx;cfg.P0(:).'];
if ~isempty(cfg.walls)
    points=[points;cfg.walls(:,1:2);cfg.walls(:,3:4)];
end
lo=min(points,[],1);hi=max(points,[],1);
side=max([hi-lo 16]);
center=(lo+hi)/2;
h=0.72*side;
b=[center(1)-h center(1)+h center(2)-h center(2)+h];
end

function h=blankHistory()
h=struct('time',zeros(1,0), ...
    'truePosition',zeros(2,0),'rawPosition',zeros(2,0), ...
    'trackPosition',zeros(2,0),'rawError',zeros(1,0), ...
    'trackError',zeros(1,0),'localBound',zeros(1,0), ...
    'deltad',zeros(3,0));
end
