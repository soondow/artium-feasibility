function S = score_mspc_model(X, model)
%SCORE_MSPC_MODEL T2 및 Q 잔차 통계량으로 HRV window를 점수화한다.

    Z = (X - model.mu) ./ model.sigma;
    completeRows = all(isfinite(Z), 2);

    T2 = nan(size(X, 1), 1);
    Q = nan(size(X, 1), 1);
    T2Norm = nan(size(X, 1), 1);
    QNorm = nan(size(X, 1), 1);
    mspcScore = nan(size(X, 1), 1);

    P = model.coeff(:, 1:model.numPC);
    latent = model.latent(1:model.numPC);

    scores = Z(completeRows, :) * P;
    T2(completeRows) = sum((scores .^ 2) ./ latent', 2);

    ZHat = scores * P';
    E = Z(completeRows, :) - ZHat;
    Q(completeRows) = sum(E .^ 2, 2);

    T2Norm(completeRows) = T2(completeRows) ./ max(model.T2_limit, eps);
    QNorm(completeRows) = Q(completeRows) ./ max(model.Q_limit, eps);
    mspcScore(completeRows) = max(T2Norm(completeRows), QNorm(completeRows));
    mspcScore = min(max(mspcScore, 0), 5);

    S = table(T2, Q, T2Norm, QNorm, mspcScore, completeRows, ...
        'VariableNames', {'T2', 'Q', 'T2_norm', 'Q_norm', 'mspc_score', 'complete_row'});
end
