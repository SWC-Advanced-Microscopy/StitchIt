function notify(message)
% Notify user of events during acquisition of section data
%
% function stitchit.tools.notify(message)
%
% Purpose
% Send a message (currently only set up for Slack) regarding analysis state.
% 
%
%

	userConfig=readStitchItINI;
    config = userConfig.syncAndCrunch;

	if ~isfield(config,'notifications')
		fprintf('%s no notifications key in INI file for message %s\n',mfilename,message)
		return
	end


	if config.notifications==0
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
