function volume_ml = compute_la_volume(lab, infoLab)
    labBin = lab > 0;

    voxelCount = nnz(labBin);

    spacing = infoLab.PixelDimensions; % [dx, dy, dz] 간격
    voxelVolMm3 = spacing(1) * spacing(2) * spacing(3);

    volume_ml = (voxelCount * voxelVolMm3) / 1000;
end