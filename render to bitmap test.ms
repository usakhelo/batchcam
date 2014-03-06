tempbitmap = bitmap 800 600 filename:@"D:\Work\3dsmax project folder\scenes\test.jpg" gamma:0.4545
render progressbar:true fromframe:0 toframe:5 camera:tempcam frame:0 to:tempbitmap
save tempbitmap
close tempbitmap