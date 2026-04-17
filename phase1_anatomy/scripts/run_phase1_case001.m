addpath(fullfile(pwd, 'config'));
P = paths_local();

addpath(fullfile(P.phase1Root, 'functions'));

imgPath = fullfile(P.dataNifti, 'case_001_img.nii.gz');
labPath = fullfile(P.dataNifti, 'case_001_lab.nii.gz');

[img, lab, infoImg, infoLab] = load_case_nifti(imgPath, labPath);

laVol = compute_la_volume(lab, infoLab);

if ~exist(P.outTable, 'dir')
    mkdir(P.outTable);
end

T = table("case_001", laVol, 'VariableNames',{'patiend_id',"la_volume_ml"});
writetable(T, fullfile(P.outTable, 'phase1_case001.csv'));

disp(T)
fprintf('LA volume = %.2f mL\n', laVol);