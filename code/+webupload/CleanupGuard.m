classdef CleanupGuard < handle
    % Runs a task when it goes out of scope, unless it was disarmed first
    %
    % guard = webupload.CleanupGuard(@() delete(file));
    % ... work that may fail or be interrupted with Ctrl-C ...
    % guard.disarm();   % the work succeeded, the task is no longer wanted
    %
    % Purpose
    % Like onCleanup, but the task can be cancelled. Used by the background upload: a temp
    % file must be deleted if anything goes wrong before the launched command takes
    % ownership of it, and must be left alone afterwards. MATLAB destroys the object when
    % the variable holding it goes out of scope, which also happens on Ctrl-C. Errors in
    % the task are reported as a warning (webupload:cleanupFailed), not thrown, because they
    % must not mask the error that caused the cleanup.

    properties (Access = private)
        Task
    end

    methods
        function obj = CleanupGuard(task)
            % task - function handle taking no arguments.
            obj.Task = task;
        end

        function disarm(obj)
            % Cancel the task
            obj.Task = [];
        end

        function delete(obj)
            if ~isempty(obj.Task)
                try
                    obj.Task();
                catch err
                    warning('webupload:cleanupFailed', 'Cleanup failed: %s', err.message);
                end
            end
        end
    end
end % CleanupGuard
