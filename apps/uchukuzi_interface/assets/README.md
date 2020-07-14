To mangle optimizely:
    
    "deploy": "elm-typescript-interop && parcel build ./index.ts ./css/app.css --out-dir ../priv/static --no-source-maps && uglifyjs ../priv/static/index.js --compress 'pure_funcs=\"F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9\",pure_getters,keep_fargs=false,unsafe_comps,unsafe' | uglifyjs --mangle  | cat > ../priv/static/index.min.js ",

    or maybe use 
        uglifyjs elm.js --no-rename --compress 'pure_funcs="F2,F3,F4,F5,F6,F7,F8,F9,A2,A3,A4,A5,A6,A7,A8,A9",pure_getters=true,keep_fargs=false,unsafe_comps=true,unsafe=true,passes=2' --mangle --output=elm.js
