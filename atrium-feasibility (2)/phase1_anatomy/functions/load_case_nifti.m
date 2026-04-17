function [img, lab, infoImg, infoLab] = load_case_nifti(imgPath, labPath)
    infoImg = niftiinfo(imgPath);
    infoLab = niftiinfo(labPath);

    img = double(niftiread(infoImg));
    lab = double(niftiread(infoLab));
end