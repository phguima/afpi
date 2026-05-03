sudo dnf install remove-retired-packages                                                                                                                                                                                   (0)
remove-retired-packages
Updating and loading repositories:
Repositories loaded.
Package                                                                       Arch             Version                                                                        Repository                                       Size
Installing:
 remove-retired-packages                                                      noarch           0:44.1-1.fc44                                                                  updates                                      23.5 KiB

Transaction Summary:
 Installing:         1 package

Total size of inbound packages is 19 KiB. Need to download 19 KiB.
After this operation, 24 KiB extra will be used (install 24 KiB, remove 0 B).
Is this ok [y/N]: y
[1/1] remove-retired-packages-0:44.1-1.fc44.noarch                                                                                                                                         100% | 103.3 KiB/s |  19.2 KiB |  00m00s
-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
[1/1] Total                                                                                                                                                                                100% |  18.3 KiB/s |  19.2 KiB |  00m01s
Running transaction
[1/3] Verify package files                                                                                                                                                                 100% | 500.0   B/s |   1.0   B |  00m00s
[2/3] Prepare transaction                                                                                                                                                                  100% |   5.0   B/s |   1.0   B |  00m00s
[3/3] Installing remove-retired-packages-0:44.1-1.fc44.noarch                                                                                                                              100% |  97.4 KiB/s |  24.7 KiB |  00m00s
Complete!
Looking for retired packages between Fedora Linux 43 and Fedora Linux 44
Retired packages are no longer maintained. Answer N to the following questions to keep them,
but these packages will not get any updates. Not even security updates.
Gathering package list for Fedora Linux 43
No matches were found for the following plugin name patterns while disabling libdnf plugins: local
No matches were found for the following plugin name patterns while disabling libdnf plugins: local
Gathering package list for Fedora Linux 44
No matches were found for the following plugin name patterns while disabling libdnf plugins: local
No matches were found for the following plugin name patterns while disabling libdnf plugins: local
Asking for super user access:
These packages have been retired:
libvdpau-va-gl: VDPAU driver with OpenGL/VAAPI back-end
Removing libvdpau-va-gl: VDPAU driver with OpenGL/VAAPI back-end
Reason of retirement: VDPAU is defacto deprecated - package also unmaintained upstream
Package                                                                       Arch             Version                                                                        Repository                                       Size
Removing:
 libvdpau-va-gl                                                               x86_64           0:0.4.2-30.fc43                                                                fedora                                      198.7 KiB

Transaction Summary:
 Removing:           1 package

After this operation, 199 KiB will be freed (install 0 B, remove 199 KiB).







