# as_latex snapshot is stable for notation = 'both'

    Code
      cat(as_latex(sym, notation = "both"))
    Output
      \text{(index notation)}
      \begin{aligned}
      W_i \mid \mu_i,\, \sigma_i & \sim \mathrm{Normal}(\mu_i,\, \sigma_i^2) \\
      \mu_i & = \beta_{0} + \beta_{1} \, T_i \\
      \log(\sigma_i) & = \gamma_{0} + \gamma_{1} \, T_i
      \end{aligned}
      \text{(matrix notation)}
      \begin{aligned}
      \mathbf{w} \mid \boldsymbol{\mu},\, \boldsymbol{\sigma} & \sim \mathcal{N}(\boldsymbol{\mu},\, \mathrm{diag}(\boldsymbol{\sigma}^2)) \\
      \boldsymbol{\mu} & = \mathbf{X} \boldsymbol{\beta} \\
      \log(\boldsymbol{\sigma}) & = \mathbf{X}_{\sigma} \boldsymbol{\gamma}
      \end{aligned}

