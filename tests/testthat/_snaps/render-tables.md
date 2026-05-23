# symbol_table print method is stable

    Code
      print(symbol_table(sym))
    Message
      
      -- Symbol dictionary ("both") --
      
      body_mass [response]
      index: `W_i`
      matrix: `\mathbf{w}`
      units: "g"
      dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
      response variable
      temperature [predictor]
      index: `T_i`
      matrix: `(no matrix form)`
      units: "C"
      dimension: `column of design matrix` (= `column of X (length 80)`)
      continuous predictor
      (parameter)
      index: `\mu_i`
      matrix: `\boldsymbol{\mu}`
      dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
      conditional mu of body_mass
      (parameter)
      index: `\sigma_i`
      matrix: `\boldsymbol{\sigma}`
      dimension: `\mathbb{R}^n` (= `\mathbb{R}^{80}`)
      conditional sigma of body_mass
      (coefficient)
      index: `\beta_{0}, \beta_{1}`
      matrix: `\boldsymbol{\beta}`
      dimension: `\mathbb{R}^{p_\mu}` (= `\mathbb{R}^{2}`)
      mu submodel coefficients
      (coefficient)
      index: `\gamma_{0}, \gamma_{1}`
      matrix: `\boldsymbol{\gamma}`
      dimension: `\mathbb{R}^{p_\sigma}` (= `\mathbb{R}^{2}`)
      sigma submodel coefficients
      (design_matrix)
      index: `(no index form)`
      matrix: `\mathbf{X}`
      dimension: `\mathbb{R}^{n \times p_\mu}` (= `\mathbb{R}^{80 \times 2}`)
      mu submodel design matrix
      (design_matrix)
      index: `(no index form)`
      matrix: `\mathbf{Z}`
      dimension: `\mathbb{R}^{n \times p_\sigma}` (= `\mathbb{R}^{80 \times 2}`)
      sigma submodel design matrix

# assumption_table print method is stable

    Code
      print(assumption_table(sym))
    Message
      
      -- Assumptions --
      
      conditional_distribution
      expression: `W_i \mid \mu_i\, \sigma_i \sim \mathrm{Normal}(\mu_i\,
      \sigma_i^2)`
      meaning: body_mass varies normally around its expected value
      status: ["stated"]
      linear_predictor (mu)
      expression: `\mu_i = \beta_0 + \sum_k \beta_k X_{ki}`
      meaning: Expected body_mass is a linear combination of the mean-model
      predictors
      status: ["stated"]
      linear_predictor (sigma)
      expression: `\log(\sigma_i) = \gamma_0 + \sum_k \gamma_k Z_{ki}`
      meaning: Log residual SD of body_mass is a linear combination of the
      scale-model predictors
      status: ["stated"]
      independence
      expression: `W_i \perp W_j \mid X \text{ for } i \ne j`
      meaning: Observations are conditionally independent given the predictors
      status: ["implied"]
      positivity (sigma)
      expression: `\sigma_i > 0`
      meaning: Residual SD is constrained positive via the log link
      status: ["implied"]
      no_missing_at_random
      expression: `—`
      meaning: Observations are assumed not missing in a way that depends on the
      unobserved response
      status: ["not_checked"]

# formula_bridge print method is stable

    Code
      print(formula_bridge(sym))
    Message
      
      -- Formula bridge ("both") --
      
      mu
      R: `body_mass ~ temperature`
      meaning: Expected body_mass is a linear function of the mean-model predictors
      math: `\mu_i = \beta_{0} + \beta_{1} \, T_i`
      matrix: `\boldsymbol{\mu} = \mathbf{X} \boldsymbol{\beta}`
      sigma
      R: `sigma ~ temperature`
      meaning: Log residual SD of body_mass is a linear function of the scale-model
      predictors
      math: `\log(\sigma_i) = \gamma_{0} + \gamma_{1} \, T_i`
      matrix: `\log(\boldsymbol{\sigma}) = \mathbf{Z} \boldsymbol{\gamma}`

