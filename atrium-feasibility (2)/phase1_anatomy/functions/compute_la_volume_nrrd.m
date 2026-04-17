function volume_ml = compute_la_volume_nrrd(labVol, labInfo)
    labMask = labVol > 0;
    voxelCount = nnz(labMask);

    spacing = labInfo.PixelDimensions;
    voxelVolMm3 = spacing(1) * spacing(2) * spacing(3);

    volume_ml = (voxelCount * voxelVolMm3) / 1000;
end
