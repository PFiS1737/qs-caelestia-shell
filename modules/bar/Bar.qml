pragma ComponentBehavior: Bound

import qs.services
import qs.config
import "popouts" as BarPopouts
import "components"
import "components/workspaces"
import Quickshell
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: root

    required property ShellScreen screen
    required property PersistentProperties visibilities
    required property BarPopouts.Wrapper popouts
    readonly property int vPadding: Appearance.padding.large

    function checkPopout(x, y, button): bool {
        if (x > implicitWidth)
            return false;

        const ch = childAt(width / 2, y) as WrappedLoader;

        const {
            has,
            name,
            item
        } = checkPopoutActiveWindow(ch, y) || checkPopoutState(ch, y) || (button === Qt.RightButton && checkPopoutTray(ch, y));

        if (has && (popouts.hasCurrent === false || name !== popouts.currentName)) {
            popouts.currentName = name;
            popouts.currentCenter = item.mapToItem(root, 0, item.implicitHeight / 2).y;
            popouts.hasCurrent = true;
            return true;
        } else if (popouts.hasCurrent) {
            popouts.hasCurrent = false;
            return false;
        }
    }

    function checkPopoutActiveWindow(ch, y) {
        if (ch?.id === "activeWindow") {
            return {
                has: true,
                name: "activewindow",
                item: ch.item
            };
        }
    }

    function checkPopoutTray(ch, y) {
        if (ch?.id === "tray") {
            const top = ch.y;
            const item = ch.item;
            const itemHeight = item.implicitHeight;
            const index = Math.floor(((y - top) / itemHeight) * item.items.count);
            const trayItem = item.items.itemAt(index);
            if (trayItem) {
                return {
                    has: true,
                    name: `traymenu${index}`,
                    item: trayItem
                };
            }
        }
    }

    function checkPopoutState(ch, y) {
        if (ch?.id === "statusIcons") {
            const items = ch.item.items;
            const icon = items.childAt(items.width / 2, mapToItem(items, 0, y).y);
            if (icon) {
                return {
                    has: true,
                    name: icon.name,
                    item: icon
                };
            }
        }
    }

    function handleWheel(y: real, angleDelta: point): void {
        const ch = childAt(width / 2, y) as WrappedLoader;
        if (ch?.id === "workspaces") {
            // Workspace scroll
            const mon = (Config.bar.workspaces.perMonitorWorkspaces ? Hypr.monitorFor(screen) : Hypr.focusedMonitor);
            const specialWs = mon?.lastIpcObject.specialWorkspace.name;
            if (specialWs?.length > 0)
                Hypr.dispatch(`togglespecialworkspace ${specialWs.slice(8)}`);
            else if (angleDelta.y < 0 || (Config.bar.workspaces.perMonitorWorkspaces ? mon.activeWorkspace?.id : Hypr.activeWsId) > 1)
                Hypr.dispatch(`workspace r${angleDelta.y > 0 ? "-" : "+"}1`);
        } else if (y < screen.height / 2) {
            // Volume scroll on top half
            if (angleDelta.y > 0)
                Audio.incrementVolume();
            else if (angleDelta.y < 0)
                Audio.decrementVolume();
        } else {
            // Brightness scroll on bottom half
            const monitor = Brightness.getMonitorForScreen(screen);
            if (angleDelta.y > 0)
                monitor.setBrightness(monitor.brightness + 0.1);
            else if (angleDelta.y < 0)
                monitor.setBrightness(monitor.brightness - 0.1);
        }
    }

    spacing: Appearance.spacing.normal

    Repeater {
        id: repeater

        model: Config.bar.entries

        DelegateChooser {
            role: "id"

            DelegateChoice {
                roleValue: "spacer"
                delegate: WrappedLoader {
                    Layout.fillHeight: enabled
                }
            }
            DelegateChoice {
                roleValue: "logo"
                delegate: WrappedLoader {
                    sourceComponent: OsIcon {}
                }
            }
            DelegateChoice {
                roleValue: "workspaces"
                delegate: WrappedLoader {
                    sourceComponent: Workspaces {
                        screen: root.screen
                    }
                }
            }
            DelegateChoice {
                roleValue: "activeWindow"
                delegate: WrappedLoader {
                    sourceComponent: ActiveWindow {
                        bar: root
                        monitor: Brightness.getMonitorForScreen(root.screen)
                    }
                }
            }
            DelegateChoice {
                roleValue: "tray"
                delegate: WrappedLoader {
                    sourceComponent: Tray {}
                }
            }
            DelegateChoice {
                roleValue: "clock"
                delegate: WrappedLoader {
                    sourceComponent: Clock {}
                }
            }
            DelegateChoice {
                roleValue: "statusIcons"
                delegate: WrappedLoader {
                    sourceComponent: StatusIcons {}
                }
            }
            DelegateChoice {
                roleValue: "power"
                delegate: WrappedLoader {
                    sourceComponent: Power {
                        visibilities: root.visibilities
                    }
                }
            }
            DelegateChoice {
                roleValue: "idleInhibitor"
                delegate: WrappedLoader {
                    sourceComponent: IdleInhibitor {}
                }
            }
        }
    }

    component WrappedLoader: Loader {
        required property bool enabled
        required property string id
        required property int index

        function findFirstEnabled(): Item {
            const count = repeater.count;
            for (let i = 0; i < count; i++) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        function findLastEnabled(): Item {
            for (let i = repeater.count - 1; i >= 0; i--) {
                const item = repeater.itemAt(i);
                if (item?.enabled)
                    return item;
            }
            return null;
        }

        Layout.alignment: Qt.AlignHCenter

        // Cursed ahh thing to add padding to first and last enabled components
        Layout.topMargin: findFirstEnabled() === this ? root.vPadding : 0
        Layout.bottomMargin: findLastEnabled() === this ? root.vPadding : 0

        visible: enabled
        active: enabled
    }
}
