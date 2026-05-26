function switchCount = count_policy_transitions(policy)
%COUNT_POLICY_TRANSITIONS Count changes in final policy labels.

    policy = string(policy(:));

    if isempty(policy)
        switchCount = 0;
        return;
    end

    switchCount = nnz(policy(2:end) ~= policy(1:end-1));
end
