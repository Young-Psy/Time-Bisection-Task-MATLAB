
function [] = time_bisect_learn_231017
clearvars; close all; clc;
%% Get sub&Exp information
expinfo       = [];
dlgprompt     = {'Subject ID:',...
             'Age:',...
             'Session number:'};
dlgname       = 'Sub&Exp Information';
numlines      = 1;
defaultanswer = {'S20','0','1'};
ans1          = inputdlg(dlgprompt,dlgname,numlines,defaultanswer);
expinfo.id    = ans1{1};
expinfo.age   = str2num(ans1{2});
expinfo.sess  = ans1{3};
expinfo.backcolr = 128;
expinfo.instcolr = 255;

sexStrList    = {'Female','Male'};
handStrList   = {'Right','Left'};
[sexidx,v]    = listdlg('PromptString','Gender:','SelectionMode','Single','ListString',sexStrList);
expinfo.sex   = sexStrList{sexidx};
if ~v; expinfo.sex  = 'NA'; end
[handidx,v]   = listdlg('PromptString','Handedness:','SelectionMode','Single','ListString',handStrList);
expinfo.hand  = handStrList{handidx};
if ~v; expinfo.hand = 'NA'; end

% Specify responses keys.
KbName('UnifyKeyNames');
quitKey  = KbName('escape');
spaceKey = KbName('space');
shortKey = KbName('leftarrow');
longKey  = KbName('rightarrow');
while KbCheck; end
ListenChar(2);

% Set the folder and filename for data save
destdir = './timebisect/learn/';
if ~exist(destdir,'dir'), mkdir(destdir); end
expinfo.path2save = fullfile(destdir, ['timebisect_', expinfo.id, '_learn_sesssion', expinfo.sess, '_', datestr(now,30)]);

% Specify screen window parameters.
viewDistance = 60; % viewing distance (cm)
Screens      = Screen('Screens'); % Screen indices (in case with multiple screens)
whichScreen  = max(Screens);      % Which screen(s) to use
winRect      = [];                % The upper left and lower right points of the to-be-opened window, default to full screen window
pixDepth     = 32;                % Pixel depth (R, G, B, and alpha), default is to leave depth unchanged
numBuffer    = 2;                 % Number of screen buffers
stereoMode   = 0;                 % Type of stereo display algorithm to use, default is 0 with monoscopic viewing
multiSample  = 0;                 % If the value is greater than 0, automatic hardware anti-aliasing of the display is enabled
imagingMode  = [];                % A parameter that enables PTB's internal image processing pipeline, default is off
%% Standard coding, use try/catch to allow cleanup on error
try
    % This script calls Psychtoolbox commands available only in
    % OpenGL-based versions of Psychtoolbox. The Psychtoolbox command
    % AssertPsychOpenGL will issue an error message if someone tries to
    % execute this script on a computer without an OpenGL Psychtoolbox.
    AssertOpenGL;
    
    % Screen is able to do a lot of configuration and performance checks on
	% open, and will print out a fair amount of detailed information when
	% it does. These commands supress that checking behavior and just let
    % the program go straight into action. See ScreenTest for an example of
    % how to do detailed checking.
	oldVisualDebugLevel    = Screen('Preference','VisualDebugLevel',3);
    oldSuppressAllWarnings = Screen('Preference','SuppressAllWarnings',1);
    
    % Open a screen window and get window information.
    [winPtr, winRect] = Screen('OpenWindow',whichScreen,expinfo.backcolr,winRect,pixDepth,numBuffer,stereoMode,multiSample,imagingMode);
    Screen('BlendFunction',winPtr,GL_SRC_ALPHA,GL_ONE_MINUS_SRC_ALPHA);
    Screen('TextSize', winPtr, 30);
    Screen('TextFont', winPtr, 'Kaiti');
    [x0, y0] = RectCenter(winRect);
    [width_mm, height_mm] = Screen('DisplaySize', whichScreen);
    [width_px, height_px] = Screen('WindowSize', whichScreen);
    ifi = Screen('GetFlipInterval', winPtr);
    screenSize = [width_mm/10, height_mm/10]; %convert screenSize to cm
    winResolution = [winRect(3)-winRect(1),winRect(4)-winRect(2)];
    ppd = viewDistance*tan(pi/180)*winResolution./screenSize;
    
    data         = [];
    data.expinfo = expinfo;
    save(expinfo.path2save,'data');
    
    % Hide mouse curser and set the priority level
    HideCursor;
    priorityLevel = MaxPriority(winPtr);
    Priority(priorityLevel);
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    
    %% Prepare stimuli
    % Fixation circle
    fix_size  = [0.40 0.40]; % [H, V] in degrees of visual angle
    fix_color = expinfo.instcolr;
    fix_hv = [round(fix_size(1)*ppd(1)), round(fix_size(2)*ppd(2))];
    fix_xy = [-round(fix_hv(1)/2), round(fix_hv(1)/2), 0, 0; ...
        0, 0, -round(fix_hv(2)/2), round(fix_hv(2)/2)];
    fix_penWidth = round(0.05*ppd(1));
    % Target stimulus - Gaussian blob
    target_size      = [10.0 10.0]; 
    target_sigma     = [0.8 0.8];%[H, V] in degrees of visual angle
    target_contrast  = 0.8;
    target_hv = [min(width_px,round(target_size(1)*ppd(1))),...
        min(height_px,round(target_size(2)*ppd(2)))];
    target_hv = floor(target_hv / 2);
    target_sigma = [round(target_sigma(1)*ppd(1)),round(target_sigma(2)*ppd(2))];
    [X, Y] = meshgrid(-target_hv(1)+1:target_hv(1)-1, -target_hv(2)+1:target_hv(2)-1);
    Z = exp(-((X/target_sigma(1)).^2+(Y/target_sigma(2)).^2)/2);
    blob = floor(expinfo.backcolr * (1 + target_contrast * Z));
    blob_tex = Screen('MakeTexture', winPtr, blob);
    
    %% Learning session
    data.learning = [];
    
    instr = double(['接下来您将熟悉标准短时长和标准长时长。\n\n' ...
        '每次试验屏幕将显示“短时长”或“长时长”提示，\n\n' ...
        '请您在刺激呈现完后，按相应的反应键。\n\n' ...
        '标准短时长，请按左键；标准长时长，请按右键。\n\n\n\n' ...
        '如果您了解了任务，请按空格键开始。']);
    Screen('TextFont', winPtr, 'Kaiti');
    Screen('TextSize', winPtr, 36);
    DrawFormattedText(winPtr, instr, 'center', 'center', expinfo.instcolr);
    Screen('Flip', winPtr);
    while 1
        [keydown, keytime, keycode] = KbCheck;
        if keydown
            if keycode(spaceKey) || keycode(quitKey);	break;	end
        end
    end
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    KbReleaseWait;
    WaitSecs(0.5);

    % organize trial sequence
    trlseq = [0.4, 0.8, 0.4, 0.8, 0.4, 0.8, 0.4, 0.8, 0.4, 0.8];
    trlmin = min(trlseq);
    trlmax = max(trlseq);
    iti = 1.2 + 0.4 * rand(1, length(trlseq));
    
    % Present trials
    tmpdata = [];
    for trl=1:length(trlseq)
        switch trlseq(trl)
            case trlmin
                trlcue = double('短时长');
            case trlmax
                trlcue = double('长时长');
            otherwise
                ShowCursor;
                Priority(0);
                Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
                Screen('Preference', 'SuppressAllWarnings', oldSuppressAllWarnings);
                sca;
                error('The selection of duration is wrong, please check.');
        end
        WaitSecs(iti(trl));
        Screen('TextFont', winPtr, 'Kaiti');
        Screen('TextSize', winPtr, 36);
        Screen('DrawLines', winPtr, fix_xy, fix_penWidth, expinfo.instcolr, [x0, y0]);
        DrawFormattedText(winPtr, trlcue, 'center', y0-50, expinfo.instcolr);
        Screen('Flip', winPtr);
        WaitSecs(0.5);
        Screen('DrawLines', winPtr, fix_xy, fix_penWidth, expinfo.instcolr, [x0, y0]);
        Screen('Flip', winPtr);
        WaitSecs(0.5);
        
        Screen('DrawLines', winPtr, fix_xy, fix_penWidth, expinfo.instcolr, [x0, y0]);
        Screen('DrawTexture', winPtr, blob_tex);
        vbl = Screen('Flip', winPtr);
        t_on = vbl;
        Screen('DrawLines', winPtr, fix_xy, fix_penWidth, expinfo.instcolr, [x0, y0]);
        vbl = Screen('Flip', winPtr, vbl+(trlseq(trl)/ifi-0.1)*ifi);
        t_off = vbl;

        while 1
            [keydown, keytime, keycode] = KbCheck;
            if keydown
                if keycode(shortKey) || keycode(longKey);	break;	end
            end
        end
        KbReleaseWait;

        tmpdata.whichtrial(trl) = trlseq(trl);
        tmpdata.duration(trl)   = round(t_off - t_on, 3);
        if keycode(longKey)
            tmpdata.response(trl) = 1;
            if trlseq(trl)==trlmax
                tmpdata.correctness(trl) = 1;
            elseif trlseq(trl)==trlmin
                tmpdata.correctness(trl) = 0;
            else
                tmpdata.correctness(trl) = nan;
            end
        elseif keycode(shortKey)
            tmpdata.response(trl) = 0;
            if trlseq(trl)==trlmin
                tmpdata.correctness(trl) = 1;
            elseif trlseq(trl)==trlmax
                tmpdata.correctness(trl) = 0;
            else
                tmpdata.correctness(trl) = nan;
            end
        end
        tmpdata.rt(trl) = round(keytime - t_off, 3);
    end
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    
    data.learning = tmpdata;
    save(expinfo.path2save,'data');
    
    %% Practice session
    data.practice = [];
    
    instr = double(['接下来我们将给您随机呈现光点。\n\n' ...
        '每次开始的时候将不再给您提示，\n\n' ...
        '请您在光点呈现后，按相应的反应键。\n\n' ...
        '标准短时长，请按左键；标准长时长，请按右键。\n\n\n\n' ...
        '如果您了解了任务，请按空格键开始练习。']);
    Screen('TextFont', winPtr, 'Kaiti');
    Screen('TextSize', winPtr, 36);
    DrawFormattedText(winPtr, instr, 'center', 'center', expinfo.instcolr);
    Screen('Flip', winPtr);
    while 1
        [keydown, keytime, keycode] = KbCheck;
        if keydown
            if keycode(spaceKey) || keycode(quitKey);	break;	end
        end
    end
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    KbReleaseWait;
    
    blk = 0;
    while 1
        if keycode(quitKey);	break;	end
        blk = blk + 1;
        
        % organize trial sequence
        trlseq = Shuffle(repmat([0.4, 0.8], 1, 4));
        trlmin = min(trlseq);
        trlmax = max(trlseq);
        iti = 1.2 + 0.4 * rand(1, length(trlseq));
        
        % Present trials
        tmpdata = [];
        for trl=1:length(trlseq)
            WaitSecs(iti(trl));
            Screen('DrawLines', winPtr, fix_xy, fix_penWidth, fix_color, [x0, y0]);
            Screen('DrawTexture', winPtr, blob_tex);
            vbl = Screen('Flip', winPtr);
            t_on = vbl;
            Screen('DrawLines', winPtr, fix_xy, fix_penWidth, fix_color, [x0, y0]);
            vbl = Screen('Flip', winPtr, vbl+(trlseq(trl)/ifi-0.1)*ifi);
            t_off = vbl;

            while 1
                [keydown, keytime, keycode] = KbCheck;
                if keydown
                    if keycode(shortKey) || keycode(longKey);	break;	end
                end
            end
            KbReleaseWait;

            tmpdata.whichtrial(trl) = trlseq(trl);
            tmpdata.duration(trl)   = round(t_off - t_on, 3);
            if keycode(longKey)
                tmpdata.response(trl) = 1;
                if trlseq(trl) == trlmax
                    tmpdata.correctness(trl) = 1;
                elseif trlseq(trl) == trlmin
                    tmpdata.correctness(trl) = 0;
                else
                    tmpdata.correctness(trl) = nan;
                end
            elseif keycode(shortKey)
                tmpdata.response(trl) = 0;
                if trlseq(trl) == trlmin
                    tmpdata.correctness(trl) = 1;
                elseif trlseq(trl) == trlmax
                    tmpdata.correctness(trl) = 0;
                else
                    tmpdata.correctness(trl) = nan;
                end
            end
            tmpdata.rt(trl) = round(keytime - t_off, 3);
        end
        
        data.practice{blk} = tmpdata;
        save(expinfo.path2save,'data');
        
        if sum(tmpdata.correctness)==length(tmpdata.correctness);   break;  end
    end
    
    %% End session
    instr = double(['实验到此结束。\n\n' ...
        '非常感谢您的参与。']);
    Screen('TextFont', winPtr, 'Kaiti');
    Screen('TextSize', winPtr, 42);
    DrawFormattedText(winPtr, instr, 'center', 'center', expinfo.instcolr);
    Screen('Flip', winPtr);
    WaitSecs(2.0);
    
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    ListenChar(0);
    
    % Restore preferences
    Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
    Screen('Preference', 'SuppressAllWarnings', oldSuppressAllWarnings);
catch
    %% Catch error.
    Screen('FillRect', winPtr, expinfo.backcolr);
    Screen('Flip', winPtr);
    Screen('CloseAll');
    ShowCursor;
    Priority(0);
    ListenChar(0);
    
    % Restore preferences
    Screen('Preference', 'VisualDebugLevel', oldVisualDebugLevel);
    Screen('Preference', 'SuppressAllWarnings', oldSuppressAllWarnings);
    
    psychrethrow(psychlasterror);
end % try ... catch %
end