pragma Singleton

import Quickshell

Singleton {
    id: root

    property var stack: []

    function focus(comp) {
        const idx = stack.indexOf(comp);

        if (idx === -1) {
            stack.push(comp);
        } else {
            stack.splice(idx, 1);
            stack.push(comp);
        }

        comp.focus = true;
    }

    function blur() {
        const comp = stack.pop();
        if (comp) {
            comp.focus = false;
            if (stack.length) {
                const comp = stack[stack.length - 1];
                if (comp) {
                    comp.focus = true;
                }
            }
        }
    }
}
