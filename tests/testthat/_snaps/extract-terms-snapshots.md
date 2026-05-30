# multi-level factor produces one row per contrast level

    Code
      print_full(result)
    Output
      # A tibble: 3 x 9
        submodel term_label  variable role            contrast_level transform symbol             coefficient_symbol latex_term                           
        <chr>    <chr>       <chr>    <chr>           <chr>          <chr>     <chr>              <chr>              <chr>                                
      1 mu       (Intercept) <NA>     intercept       <NA>           ""         <NA>              "\\beta_{0}"       "\\beta_{0}"                         
      2 mu       site        site     factor_contrast B              ""        "\\mathrm{site}_i" "\\beta_{1}"       "\\beta_{1} \\, [site = \\mathrm{B}]"
      3 mu       site        site     factor_contrast C              ""        "\\mathrm{site}_i" "\\beta_{2}"       "\\beta_{2} \\, [site = \\mathrm{C}]"

# continuous x continuous interaction

    Code
      print_full(result)
    Output
      # A tibble: 4 x 9
        submodel term_label  variable role        contrast_level transform symbol            coefficient_symbol latex_term                  
        <chr>    <chr>       <chr>    <chr>       <chr>          <chr>     <chr>             <chr>              <chr>                       
      1 mu       (Intercept) <NA>     intercept   <NA>           ""         <NA>             "\\beta_{0}"       "\\beta_{0}"                
      2 mu       x           x        predictor   <NA>           ""        "X_i"             "\\beta_{1}"       "\\beta_{1} \\, X_i"        
      3 mu       z           z        predictor   <NA>           ""        "Z_i"             "\\beta_{2}"       "\\beta_{2} \\, Z_i"        
      4 mu       x:z         x:z      interaction <NA>           ""        "\\mathrm{x:z}_i" "\\beta_{3}"       "\\beta_{3} \\, X_i \\, Z_i"

# continuous x factor interaction

    Code
      print_full(result)
    Output
      # A tibble: 4 x 9
        submodel term_label  variable role            contrast_level transform symbol              coefficient_symbol latex_term                             
        <chr>    <chr>       <chr>    <chr>           <chr>          <chr>     <chr>               <chr>              <chr>                                  
      1 mu       (Intercept) <NA>     intercept       <NA>           ""         <NA>               "\\beta_{0}"       "\\beta_{0}"                           
      2 mu       x           x        predictor       <NA>           ""        "X_i"               "\\beta_{1}"       "\\beta_{1} \\, X_i"                   
      3 mu       sex         sex      factor_contrast male           ""        "S_i"               "\\beta_{2}"       "\\beta_{2} \\, [sex = \\mathrm{male}]"
      4 mu       x:sex       x:sex    interaction     -:male         ""        "\\mathrm{x:sex}_i" "\\beta_{3}"       "\\beta_{3} \\, X_i \\, S_i"           

# factor x factor interaction

    Code
      print_full(result)
    Output
      # A tibble: 4 x 9
        submodel term_label  variable role            contrast_level transform symbol            coefficient_symbol latex_term                         
        <chr>    <chr>       <chr>    <chr>           <chr>          <chr>     <chr>             <chr>              <chr>                              
      1 mu       (Intercept) <NA>     intercept       <NA>           ""         <NA>             "\\beta_{0}"       "\\beta_{0}"                       
      2 mu       a           a        factor_contrast a2             ""        "a_i"             "\\beta_{1}"       "\\beta_{1} \\, [a = \\mathrm{a2}]"
      3 mu       b           b        factor_contrast b2             ""        "b_i"             "\\beta_{2}"       "\\beta_{2} \\, [b = \\mathrm{b2}]"
      4 mu       a:b         a:b      interaction     a2:b2          ""        "\\mathrm{a:b}_i" "\\beta_{3}"       "\\beta_{3} \\, a_i \\, b_i"       

# offset with function call (log)

    Code
      print_full(result)
    Output
      # A tibble: 3 x 9
        submodel term_label            variable role      contrast_level transform symbol coefficient_symbol latex_term          
        <chr>    <chr>                 <chr>    <chr>     <chr>          <chr>     <chr>  <chr>              <chr>               
      1 mu       (Intercept)           <NA>     intercept <NA>           ""        <NA>   "\\beta_{0}"       "\\beta_{0}"        
      2 mu       x                     x        predictor <NA>           ""        X_i    "\\beta_{1}"       "\\beta_{1} \\, X_i"
      3 mu       offset(log(exposure)) exposure offset    <NA>           "log"     E_i     <NA>              "\\mathrm{log}(E_i)"

# offset without function call

    Code
      print_full(result)
    Output
      # A tibble: 3 x 9
        submodel term_label       variable role      contrast_level transform symbol coefficient_symbol latex_term          
        <chr>    <chr>            <chr>    <chr>     <chr>          <chr>     <chr>  <chr>              <chr>               
      1 mu       (Intercept)      <NA>     intercept <NA>           ""        <NA>   "\\beta_{0}"       "\\beta_{0}"        
      2 mu       x                x        predictor <NA>           ""        X_i    "\\beta_{1}"       "\\beta_{1} \\, X_i"
      3 mu       offset(exposure) exposure offset    <NA>           ""        E_i     <NA>              "E_i"               

# scale(x) transformation

    Code
      print_full(result)
    Output
      # A tibble: 2 x 9
        submodel term_label  variable role           contrast_level transform symbol coefficient_symbol latex_term                           
        <chr>    <chr>       <chr>    <chr>          <chr>          <chr>     <chr>  <chr>              <chr>                                
      1 mu       (Intercept) <NA>     intercept      <NA>           ""        <NA>   "\\beta_{0}"       "\\beta_{0}"                         
      2 mu       scale(x)    x        transformation <NA>           "scale"   X_i    "\\beta_{1}"       "\\beta_{1} \\, \\mathrm{scale}(X_i)"

# log(z) transformation

    Code
      print_full(result)
    Output
      # A tibble: 2 x 9
        submodel term_label  variable role           contrast_level transform symbol coefficient_symbol latex_term                         
        <chr>    <chr>       <chr>    <chr>          <chr>          <chr>     <chr>  <chr>              <chr>                              
      1 mu       (Intercept) <NA>     intercept      <NA>           ""        <NA>   "\\beta_{0}"       "\\beta_{0}"                       
      2 mu       log(z)      z        transformation <NA>           "log"     Z_i    "\\beta_{1}"       "\\beta_{1} \\, \\mathrm{log}(Z_i)"

# I(x^2) identity-protected expression

    Code
      print_full(result)
    Output
      # A tibble: 3 x 9
        submodel term_label  variable role           contrast_level transform symbol            coefficient_symbol latex_term                                   
        <chr>    <chr>       <chr>    <chr>          <chr>          <chr>     <chr>             <chr>              <chr>                                        
      1 mu       (Intercept) <NA>     intercept      <NA>           ""         <NA>             "\\beta_{0}"       "\\beta_{0}"                                 
      2 mu       x           x        predictor      <NA>           ""        "X_i"             "\\beta_{1}"       "\\beta_{1} \\, X_i"                         
      3 mu       I(x^2)      x^2      transformation <NA>           "I"       "\\mathrm{x^2}_i" "\\beta_{2}"       "\\beta_{2} \\, \\mathrm{I}(\\mathrm{x^2}_i)"

# poly(x, 2) orthogonal polynomial

    Code
      print_full(result)
    Output
      # A tibble: 3 x 9
        submodel term_label  variable role           contrast_level transform symbol             coefficient_symbol latex_term                                       
        <chr>    <chr>       <chr>    <chr>          <chr>          <chr>     <chr>              <chr>              <chr>                                            
      1 mu       (Intercept) <NA>     intercept      <NA>           ""         <NA>              "\\beta_{0}"       "\\beta_{0}"                                     
      2 mu       poly(x, 2)  x, 2     transformation <NA>           "poly"    "\\mathrm{x, 2}_i" "\\beta_{1}"       "\\beta_{1} \\, \\mathrm{poly}(\\mathrm{x, 2}_i)"
      3 mu       poly(x, 2)  x, 2     transformation <NA>           "poly"    "\\mathrm{x, 2}_i" "\\beta_{2}"       "\\beta_{2} \\, \\mathrm{poly}(\\mathrm{x, 2}_i)"

# one-sided formula on sigma submodel with gamma coefficients

    Code
      print_full(result)
    Output
      # A tibble: 2 x 9
        submodel term_label  variable role      contrast_level transform symbol coefficient_symbol latex_term           
        <chr>    <chr>       <chr>    <chr>     <chr>          <chr>     <chr>  <chr>              <chr>                
      1 sigma    (Intercept) <NA>     intercept <NA>           ""        <NA>   "\\gamma_{0}"      "\\gamma_{0}"        
      2 sigma    x           x        predictor <NA>           ""        X_i    "\\gamma_{1}"      "\\gamma_{1} \\, X_i"

