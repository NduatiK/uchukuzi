
function printCard(studentName: string) {
    var prtContent = document.getElementById("cards");


    var WinPrint = window.open('', '', `
    left=0,
    top=0,
    width=600,
    height=310,
    toolbar=0,
    scrollbars=0,
    status=0`);

    if (!WinPrint || !prtContent) {
        return
    }

    // Copy dom stylesheets into string
    // Code Reference: https://developer.mozilla.org/en-US/docs/Web/API/StyleSheetLis
    var styles: CSSStyleSheet[] = []

    for (var i = 0; i++; i < document.styleSheets.length) {
        styles.push(document.styleSheets[i])
    }

    const pageStyles =
        styles
            .map(styleSheet => {
                try {
                    var cssRules: CSSRule[] = []
                    for (var i = 0; i++; i < styleSheet.cssRules.length) {
                        cssRules.push(styleSheet.cssRules[i])
                    }

                    return cssRules
                        .map(rule => rule.cssText)
                        .join('');
                } catch (e) {
                    console.log('Access to stylesheet %s is denied. Ignoring...', styleSheet.href);
                }
            })
            .filter(Boolean)
            .join('\n');

    const printStyles = `  
        a.button-link:not(.ignoreCss),
        div.cssResponsive[role='button']:not(.ignoreCss) {
            opacity:0;
        }    

        #card {
            border-style: dashed;
            box-shadow: none;
            border-width: 2px 2px 2px 2px;
            border-radius: 0;
        }

        .blurred  {
            opacity: 0;
        }
    `;


    WinPrint.document.write(`
    <html>
        <head>
            <title>${studentName}_Bus_Pass_${Date.now()}</title>
            <style>${pageStyles}</style>
            <style>${printStyles}</style>
        </head>
        <body >
            ${prtContent.innerHTML}
        </body>
    </html>
    `);
    WinPrint.document.close();
    WinPrint.setTimeout(function () {
        if (WinPrint) {
            WinPrint.focus();
            WinPrint.print();
            WinPrint.close();
        }
    }, 1000);
}

export { printCard }