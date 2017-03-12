function msg = generateMessage(msgType)
% Generate a terribly useful notification message
%
%    function msg = generateMessage(msgType)
%
%
% Purpose
% Colourful notification generator
%
% Inputs
% msgType - the message class [string]
%           'positive'
%           'negative'
%
%
% Outputs
% msg - the message string
%
%
% Rob Campbell


switch msgType
case 'positive'
    msg = positive;
case 'negative'
    msg = negative;
end

msg = msg{randi(length(msg))};



% message functions follow
function msg = positive
    msg = {...
    'This was a triumph!',...
    'Fantastic wonderfulness:',...
    'Great joy and hope!',...
    'Look! I did a really good thing:',...
    'After much toil I can announce:',...
    'I''m so awesome I amaze even myself.'};


function msg = negative
    msg = {...
    'Terrible and awful things have befallen us:',...
    'Woe! Look at all this bad shit that''s happened:',...
    'Gnashing of teeth and wailing of lost souls:',...
    'I was expecting things to go better than this:',...
    'I am ashamed to say that stuff has not gone according to plan:',...
    'Despite extensive instruction in how to handle these data I have still fucked it up:',...
    'I didn''t think things would end this badly:',...
    'I''ve run out cake. Oh, and also this happened:',...
    'I tried really hard but still things didn''t work out:',...
    'Maybe it wasn''t meant to be.'};




