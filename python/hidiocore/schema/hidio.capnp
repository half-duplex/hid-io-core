# Copyright (C) 2017-2020 by Jacob Alexander
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

@0xd525cce96cb24671;

## Imports ##

using Common = import "common.capnp";



## Interfaces ##

interface HIDIOServer {
    # Authentication interface for HIDIO

    struct Version {
        version @0 :Text;
        # Version number of running server

        buildtime @1 :Text;
        # Date server was build

        serverarch @2 :Text;
        # Architecture of running server

        compilerversion @3 :Text;
        # Version of the compiler used to build server
    }

    struct KeyInfo {
        basicKeyPath @0 :Text;
        # File path to basic key
        # Has permissions of basic user

        authKeyPath @1 :Text;
        # File path to authenticated key
        # Must have root/admin priviledges to read this key
    }

    ## Functions ##

    basic @0 (info :Common.Source, key :Text) -> (port :HIDIO);
    # Allocates a basic interface, with no special priviledges
    # Must include a key retrieved using locations specified by HIDIOInit

    auth @1 (info :Common.Source, key :Text) -> (port :HIDIO);
    # Priviledged interface
    # Must include a key retrieved using locations specified by HIDIOInit

    version @2 () -> (version :Version);
    # Returns the version number of the running server

    key @3 () -> (key :KeyInfo);
    # Returns information needed to authenticate with HIDIOServer

    alive @4 () -> (alive: Bool);
    # Always returns true, used to determine if socket connection/API is working

    id @5 () -> (id :UInt64);
    # Unique id
    # Assigned per socket connection
    # This must be used when attempting basic/auth authentication

    name @6 () -> (name :Text);
    # Name of HID-IO Server

    logFiles @7 () -> (paths :List(Text));
    # Path to the local hid-io core log file(s)
    # rCURRENT is the current active log file
}

interface HIDIO {
    # Main HIDIO Interface
    # Requires authentication through HIDIOServer first

    struct Packet {
        # This struct represents a modified HIDIO packet
        # as used internally by hid-io-core.
        # This is not the same as the "on-the-wire" HIDIO packets
        # (Continued packets are joined together)
        # TODO DOCUMENT MORE
        enum Type {
            data @0;
            # Data packet
            ack @1;
            # Ack for a data packet
            nak @2;
            # Nak for a data packet (Error)
            naData @3;
            # Non-acknowledged data packet (no corresponding ack/nak packet)
        }

        src @0 :UInt64;
        # Source uid of the packet (set to 0 if N/A)

        dst @1 :UInt64;
        # Destination uid of the packet (set to 0 if N/A)

        type @2 :Type;
        # Type of HIDIO packet

        id @3 :UInt32;
        # Id of the HIDIO packet

        data @4 :List(UInt8);
        # Payload data of packet (in bytes)
    }

    nodes @0 () -> (nodes :List(Common.Destination));
    # List of supported nodes
    # This may not contain all nodes due to authentication levels
    # The HIDIO daemon may revoke priviledges for certain modules during runtime

    interface NodesSubscription {}
    # Node subscription interface
    # Handles subscription ownership and when to drop subscription

    interface NodesSubscriber {
        # Client node subscriber
        # Handles any push methods that hid-io-core can send

        nodesUpdate @0 (nodes :List(Common.Destination));
        # Called whenever the list of nodes changes

        hidioWatcher @1 (packets :List(Packet));
        # Called on every internal HIDIO message
        # This watcher will show most of the "on-the-wire" packets as well as some hid-io-core internal packets.
        # Sync, Continued and NAContinued will not be triggered by the watcher.
        # NOTE: This callback is only used when hid-io-core is in debug mode with a priviledged interface
    }

    subscribeNodes @1 (subscriber :NodesSubscriber) -> (subscription :NodesSubscription);
    # Subscribes a NodesSubscriber interface
    # Registers push notifications for node list changes
}

interface Node extends(Common.Node) {
    # Common interface for all HIDIO nodes

    struct FlashModeStatus {
        # Result of a flash mode command

        struct Success {
            scanCode @0 :UInt16;
            # In order to enter flash mode a specific (randomly) generated physical key must be pressed
            # This scan code refers to that physical key.
            # Use the key layout to determine the HID key label.
        }
        struct Error {
            # Entering flash mode failed

            reason @0 :ErrorReason;
            # Reason for flash mode failure

            enum ErrorReason {
                notSupported @0;
                # Flash mode is not supported on this device

                disabled @1;
                # Flash mode is disabled on this device (usually for security reasons)
            }
        }

        union {
            success @0 :Success;
            error @1 :Error;
        }
    }

    struct SleepModeStatus {
        # Result of a sleep mode command

        struct Success {}
        struct Error {
            # Entering sleep mode failed

            reason @0 :ErrorReason;
            # Reason for sleep mode failure

            enum ErrorReason {
                notSupported @0;
                # Sleep mode is not supported on this device

                disabled @1;
                # Sleep mode is disabled on this device

                notReady @2;
                # Not ready to enter sleep mode
                # This is usually due to some physical or USB state that is preventing the transition to sleep mode
            }
        }

        union {
            success @0 :Success;
            error @1 :Error;
        }
    }


    cliCommand @0 (command :Text) -> ();
    # CLI command

    sleepMode @1 () -> (status :SleepModeStatus);
    # Attempt to have device go into a sleep state

    flashMode @2 () -> (status :FlashModeStatus);
    # Attempt to have the device enter flash mode
}
