function notify(message,forceLocalMessage)
% Notify user of events during acquisition of section data
%
% function stitchit.tools.notify(message,forceLocalMessage)
%
% Purpose
% Send a message (currently only set up for Slack) regarding analysis state.
% 
% 
% Inputs
% message - string to notify the user with
% forceLocalMessage - Do not send remote message even if this is set up.
%                    By default forceLocalMessage is false.
%
%
% Rob Campbell

    if nargin<2 || isempty(forceLocalMessage)
        forceLocalMessage=false;
    end

    userConfig=readStitchItINI;
    config = userConfig.syncAndCrunch;

    if ~isfield(config,'notifications')
        fprintf('%s no notifications key in INI file for message %s\n',mfilename,message)
        return
    end


    if config.notifications==0 || forceLocalMessage
        fprintf('%s\n',message)
        return
    end


    switch config.notificationProtocol
        case 'slack'
            if ~exist('SendSlackNotification','file')
                fprintf('No function SendSlackNotification for message %s\n',mfilename,message)
                return
            end

            if config.slackHook==0
                fprintf('No slackHook in INI file for message %s\n', message)
                return
            end

            if config.slackUser %attach user name if one was requested
                message = [config.slackUser, ' ', message];
            end
            SendSlackNotification(config.slackHook,message);
        otherwise
            fprintf('%s: Unknown protocol %s for message %s\n',...
            mfilename, config.notificationProtocol, message);
    end
