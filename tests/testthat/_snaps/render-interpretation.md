# print method renders a clean per-submodel summary (snapshot)

    Code
      print(parameter_interpretation(sym))
    Message
      
      -- Parameter interpretation ("all") --
      
      -- submodel: mu 
      (Intercept) ["intercept"] estimate = "29.6"
      link: Expected body_mass at the reference
      natural: Expected body_mass for the reference case
      variance: —
      biological: Baseline body_mass in the reference condition
      temperature ["slope"] estimate = "0.492"
      link: Linear change in expected body_mass per unit of temperature
      natural: Expected body_mass changes by 0.492 per unit of temperature
      variance: —
      biological: A unit change in temperature shifts the expected body_mass by 0.492
      
      -- submodel: sigma 
      (Intercept) ["intercept"] estimate = "0.485"
      link: Log residual SD at the reference (SD = exp(0.485))
      natural: Residual SD = exp(0.485) at the reference
      variance: Residual variance = exp(2*0.485)
      biological: Baseline level of unexplained individual variation in body_mass
      temperature ["slope"] estimate = "0.0936"
      link: Log residual SD changes by 0.0936 per unit of temperature
      natural: Residual SD multiplied by exp(0.0936) per unit of temperature
      variance: Residual variance multiplied by exp(2*0.0936) per unit
      biological: A unit change in temperature multiplies the unexplained variability
      of body_mass by exp(0.0936)

