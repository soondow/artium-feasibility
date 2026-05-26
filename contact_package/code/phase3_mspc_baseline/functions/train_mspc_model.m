function model = train_mspc_model(XTrain, explainedVarianceTarget)
%TRAIN_MSPC_MODEL Train a compact PCA/MSPC normal-operating-condition model.

    if nargin < 2 || isempty(explainedVarianceTarget)
        explainedVarianceTarget = 0.90;
    end

    XTrain = XTrain(all(isfinite(XTrain), 2), :);
    if size(XTrain, 1) < 5
        error('MSPC training requires at least five complete high-quality normal windows.');
    end

    mu = mean(XTrain, 1, 'omitnan');
    sigma = std(XTrain, 0, 1, 'omitnan');
    sigma(sigma == 0 | isnan(sigma)) = 1;

    Z = (XTrain - mu) ./ sigma;
    [~, S, coeff] = svd(Z, 'econ');
    latent = diag(S) .^ 2 ./ max(size(Z, 1) - 1, 1);

    explained = cumsum(latent) ./ max(sum(latent), eps);
    numPC = find(explained >= explainedVarianceTarget, 1, 'first');
    if isempty(numPC)
        numPC = numel(latent);
    end

    P = coeff(:, 1:numPC);
    scores = Z * P;
    T2Train = sum((scores .^ 2) ./ latent(1:numPC)', 2);

    ZHat = scores * P';
    E = Z - ZHat;
    QTrain = sum(E .^ 2, 2);

    model = struct();
    model.mu = mu;
    model.sigma = sigma;
    model.coeff = coeff;
    model.latent = latent;
    model.numPC = numPC;
    model.T2_limit = percentile95(T2Train);
    model.Q_limit = percentile95(QTrain);
    model.explained_variance_target = explainedVarianceTarget;
end

function y = percentile95(x)
    x = sort(x(isfinite(x)));
    if isempty(x)
        y = 1;
        return;
    end

    idx = max(1, ceil(0.95 * numel(x)));
    y = x(idx);
    if y <= 0 || isnan(y)
        y = eps;
    end
end
