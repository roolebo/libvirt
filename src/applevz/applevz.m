/*
 * applevz.m: core driver functions for managing
 *            Apple Virtualization.framework guests
 *
 * Copyright (C) 2020 Roman Bolshakov
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with this library.  If not, see
 * <http://www.gnu.org/licenses/>.
 */

#include <Virtualization/Virtualization.h>

#include "applevz_utils.h"
#include "applevz.h"

/*
int applevzCreate(applevzDriverPtr driver, virDomainDefPtr def)
{
}
*/

@interface LibvirtDelegate: NSObject <VZVirtualMachineDelegate>
- (void)guestDidStopVirtualMachine:(VZVirtualMachine *)virtualMachine;
- (void)virtualMachine:(VZVirtualMachine *)virtualMachine didStopWithError:(NSError *)error;
@end

@implementation LibvirtDelegate
- (void)guestDidStopVirtualMachine:(VZVirtualMachine *)virtualMachine
{
	NSLog(@"Stoped normally");
}

- (void)virtualMachine:(VZVirtualMachine *)virtualMachine didStopWithError:(NSError *)error
{
	    NSLog(@"Stoped with error %@", error);
}
@end

int applevzStart(virDomainObjPtr dom G_GNUC_UNUSED)
{
    NSError *configError = nil;
    NSURL *kernelURL = [NSURL URLWithString:@"file:///Users/roolebo/dev/libvirt/build/vmlinuz"];
    NSURL *initrdURL = [NSURL URLWithString:@"file:///Users/roolebo/dev/libvirt/build/initrd.gz"];
    NSURL *diskURL = [NSURL URLWithString:@"file:///Users/roolebo/dev/libvirt/build/disk"];
    NSURL *consoleURL = [NSURL URLWithString:@"file:///Users/roolebo/dev/libvirt/build/console"];
    applevzDomObjPtr privdom = dom->privateData;


    VZVirtualMachineConfiguration *config = [[VZVirtualMachineConfiguration alloc] init];
    /* TODO don't save domains that miss kernel URL */
    VZLinuxBootLoader *bootLoader = [[VZLinuxBootLoader alloc] initWithKernelURL: kernelURL];
    /* XXX if initrd exists in the domain */
    bootLoader.initialRamdiskURL = initrdURL;
    /* XXX if cmdline is not empty */
    bootLoader.commandLine =  @"console=ttyS0";
    config.bootLoader = bootLoader;
    /* XXX CPUCount is RW, can be used to change CPU live?? */
    config.CPUCount = VZVirtualMachineConfiguration.minimumAllowedCPUCount;
    /* XXX map memory */
    config.memorySize = VZVirtualMachineConfiguration.minimumAllowedMemorySize;
    /* XXX Map to libvirt entropy devices */
    config.entropyDevices = @[[[VZVirtioEntropyDeviceConfiguration alloc] init]];
    /* XXX Map to memory baloon devices */
    config.memoryBalloonDevices = @[[[VZVirtioTraditionalMemoryBalloonDeviceConfiguration alloc] init]];
    /* XXX Map to network devices */
    config.networkDevices = @[[[VZVirtioNetworkDeviceConfiguration alloc] init]];
    /* XXX Map storage devices */
    config.networkDevices = @[[[VZVirtioNetworkDeviceConfiguration alloc] init]];
    config.networkDevices[0].attachment = [[VZNATNetworkDeviceAttachment alloc] init];
    /* XXX Map serial ports */
    config.serialPorts = @[[[VZVirtioConsoleDeviceConfiguration alloc] init]];
    config.serialPorts[0].attachment = [[VZFileSerialPortAttachment alloc] initWithURL:consoleURL append:FALSE error:&configError];
    if (configError)
	    NSLog(@"%@", configError);
    /* XXX Map socket devices */
    config.socketDevices = @[[[VZVirtioSocketDeviceConfiguration alloc] init]];
    /* XXX Map storage devices */
    VZDiskImageStorageDeviceAttachment *diskAttachement = [[VZDiskImageStorageDeviceAttachment alloc] initWithURL:diskURL readOnly:FALSE error: &configError];
    if (configError)
	    NSLog(@"%@", configError);
    config.storageDevices = @[[[VZVirtioBlockDeviceConfiguration alloc] initWithAttachment: diskAttachement]];

    [config validateWithError: &configError];
    if (configError)
	    NSLog(@"%@", configError);

    dispatch_queue_t queue = dispatch_queue_create("org.libvirt.applevzd",
		                                   DISPATCH_QUEUE_SERIAL);
    dispatch_async(queue, ^{
        privdom->vzvm = [[VZVirtualMachine alloc] initWithConfiguration: config queue: queue];
	privdom->vzvm.delegate = [[LibvirtDelegate alloc] init];
	printf("vzvm init done\n");

        [privdom->vzvm startWithCompletionHandler: ^(NSError *err) {
	    NSLog(@"%@", err);
        }];
    });


    /* TODO wait for the creation */

    /*
    job = PrlVm_StartEx(privdom->sdkdom, PSM_VM_START, 0);
    if (PRL_FAILED(pret = waitDomainJob(job, dom))) {
        prlsdkConvertError(pret);
        return -1;
    }
    */

    return 0;
}
