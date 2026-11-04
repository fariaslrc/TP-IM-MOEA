function history = x1_history_append(history,X,F,C,capacity)
%X1_HISTORY_APPEND Bounded chronological LEARNING buffer, never selection.
% Append only truly evaluated data. Chronology is retained for validation.
    if isempty(history)
        history = struct('X',X,'F',F,'C',C);
    else
        history.X = [history.X;X]; history.F = [history.F;F]; history.C = [history.C;C];
    end
    keep = max(1,size(history.X,1)-capacity+1):size(history.X,1);
    history.X = history.X(keep,:); history.F = history.F(keep,:); history.C = history.C(keep,:);
end
