function compareAsides(lhs, rhs) {
    const classOrder = ['.postmeta', '.postaside', '.toc', '.aside'];
    if (lhs.className == '.aside' && rhs.className == '.aside') {
        const parseFootNum = (e) => parseInt(e.querySelector('a').id.replace('_sidedef_', ''));
        return parseFootNum(lhs) - parseFootNum(rhs);
    } else {
        const lhsOrder = classOrder.indexOf(lhs.className);
        const rhsOrder = classOrder.indexOf(rhs.className);
        return lhsOrder - rhsOrder;
    }
}

function positionAsideElements(_) {
    // Find all 'aside' elements
    const asideElements = Array.from(document.querySelectorAll('aside,.aside,.toc'));

    asideElements.sort(compareAsides);

    main_element = document.querySelector('main');
    if (main_element === null) {
        return;
    }
    baseline = main_element.getBoundingClientRect().top;

    // Iterate through the 'aside' elements from top down
    asideElements.forEach((aside, index) => {
        // Adjust the top position of each aside below the first one
        if (aside.className == 'postmeta') {
            aside.style.top = document.querySelector('h1').getBoundingClientRect().top - baseline + 'px';
        }
        if (index > 0) {
            const previousAside = asideElements[index - 1];
            const previousAsideBottom = previousAside.getBoundingClientRect().bottom;
            const myTop = aside.getBoundingClientRect().top;
            let desiredTop = myTop;

            const asideAnchor = aside.querySelector('a');
            if (asideAnchor !== null && asideAnchor.id.startsWith('_sidedef_')) {
                const anchor = document.querySelector('#' + asideAnchor.id.replace('sidedef', 'sideref'));
                const anchorTop = anchor.getBoundingClientRect().top;
                desiredTop = anchorTop;
            }

            if (previousAsideBottom > desiredTop) {
                aside.style.top = previousAsideBottom - baseline + 'px';
            } else if (myTop != desiredTop) {
                aside.style.top = desiredTop - baseline + 'px';
            }
        }
    });
}

// Run it twice because some content (particularly charts) can take
// a while to load, but can affect layout.  So the first run quickly
// gets items in about the right place, and the second one fixes up
// any minor issues once all content is fully loaded.
window.addEventListener("DOMContentLoaded", function() {
  positionAsideElements({matches: true});

  const detailsElements = document.querySelectorAll("details");
  detailsElements.forEach(function (element) {
    element.addEventListener("toggle", positionAsideElements);
  });
});
window.addEventListener("load", function() {
  positionAsideElements({matches: true});
});
window.matchMedia("(min-width: 920px)").addEventListener('change', positionAsideElements)