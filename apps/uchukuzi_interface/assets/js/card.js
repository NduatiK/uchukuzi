
function printCard(id) {
    var prtContent = document.getElementById("cards");

    // Copy dom stylesheets into string
    // Reference https://developer.mozilla.org/en-US/docs/Web/API/StyleSheetLis
    const allCSS = [...document.styleSheets]
        .map(styleSheet => {
            try {
                return [...styleSheet.cssRules]
                    .map(rule => rule.cssText)
                    .join('');
            } catch (e) {
                console.log('Access to stylesheet %s is denied. Ignoring...', styleSheet.href);
            }
        })
        .filter(Boolean)
        .join('\n');

    var WinPrint = window.open('', '', `
    left=0,
    top=0,
    width=600,
    height=310,
    toolbar=0,
    scrollbars=0,
    status=0`);


    WinPrint.document.write(`<style>
    ${allCSS}
    a.button-link:not(.ignoreCss),
    div.cssResponsive[role='button']:not(.ignoreCss) {
        opacity:0;
    }    
 
    </style>`);

    WinPrint.document.write(prtContent.innerHTML);
    WinPrint.document.close();
    WinPrint.setTimeout(function () {
        WinPrint.focus();
        WinPrint.print();
        WinPrint.close();
    }, 1000);
}

export { printCard }