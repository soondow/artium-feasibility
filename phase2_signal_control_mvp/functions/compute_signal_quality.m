function Q = compute_signal_quality(rriMs, varargin)
%COMPUTE_SIGNAL_QUALITY Estimate an RRI window signal quality index.
%
% The score is intentionally transparent for an MVP:
% - coverage penalizes missing samples
% - physiologic range penalizes RRI outside 300-2000 ms
% - artifact score penalizes robust outliers and abrupt jumps
% - continuity score penalizes beat-to-beat discontinuity

    p = inputParser;
    addRequired(p, 'rriMs', @(x) isnumeric(x) && isvector(x));
    addParameter(p, 'PhysRangeMs', [300 2000], @(x) isnumeric(x) && numel(x) == 2);
    addParameter(p, 'RobustZLimit', 8.0, @(x) isnumeric(x) && isscalar(x) && x > 0);
    addParameter(p, 'JumpFractionLimit', 0.70, @(x) isnumeric(x) && isscalar(x) && x > 0);
    parse(p, rriMs, varargin{:});

    rriMs = rriMs(:);
    n = numel(rriMs);

    missingMask = isnan(rriMs);
    coverage = 1 - mean(missingMask);

    physRange = p.Results.PhysRangeMs;
    rangeValidMask = ~missingMask & rriMs >= physRange(1) & rriMs <= physRange(2);
    rangeViolationRatio = mean(~missingMask & ~rangeValidMask);
    rangeScore = 1 - safeRatio(nnz(~missingMask & ~rangeValidMask), nnz(~missingMask));

    cleanRangeValues = rriMs(rangeValidMask);
    robustOutlierMask = false(n, 1);
    jumpOutlierMask = false(n, 1);

    if numel(cleanRangeValues) >= 8
        medRri = median(cleanRangeValues);
        madRri = median(abs(cleanRangeValues - medRri));
        robustSigma = max(1.4826 * madRri, 1);

        robustZ = abs(rriMs - medRri) ./ robustSigma;
        robustOutlierMask = rangeValidMask & robustZ > p.Results.RobustZLimit;

        validIdx = find(rangeValidMask);
        validRri = rriMs(validIdx);
        jumpMaskValid = [false; abs(diff(validRri)) > p.Results.JumpFractionLimit * medRri];
        jumpOutlierMask(validIdx) = jumpMaskValid;
    end

    artifactMask = robustOutlierMask | jumpOutlierMask;
    artifactRatio = mean(artifactMask);
    validMask = rangeValidMask & ~artifactMask;

    if numel(cleanRangeValues) >= 3
        medRri = median(cleanRangeValues);
        jumpRatio = mean(abs(diff(cleanRangeValues)) > p.Results.JumpFractionLimit * medRri);
    else
        jumpRatio = 1;
    end
    continuityScore = 1 - min(1, 2.5 * jumpRatio);
    artifactScore = 1 - min(1, 4.0 * artifactRatio);

    q = 0.45 * coverage + 0.25 * rangeScore + 0.25 * artifactScore + 0.05 * continuityScore;
    q = clip01(q);

    Q = struct();
    Q.q = q;
    Q.coverage = clip01(coverage);
    Q.range_score = clip01(rangeScore);
    Q.artifact_score = clip01(artifactScore);
    Q.continuity_score = clip01(continuityScore);
    Q.missing_ratio = safeRatio(nnz(missingMask), n);
    Q.range_violation_ratio = rangeViolationRatio;
    Q.artifact_ratio = artifactRatio;
    Q.jump_ratio = jumpRatio;
    Q.missing_mask = missingMask;
    Q.range_valid_mask = rangeValidMask;
    Q.artifact_mask = artifactMask;
    Q.valid_mask = validMask;
end

function y = safeRatio(num, den)
    if den <= 0
        y = 0;
    else
        y = num ./ den;
    end
end

function y = clip01(x)
    y = min(max(x, 0), 1);
end
