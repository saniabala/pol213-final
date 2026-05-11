# Democratic backsliding → foreign aid (do donors punish democratic decline?)
# Unit of analysis: country-year 
  # post-Cold War only? Donors may have more democracy-promoting tendencies in this time period…
# Democratic backsliding as a binary outcome (occured/did not)
  # Logit? 
  
# Rough Outline
  # Intro
    # Present puzzle: does democratic backsliding reduce foreign aid receipts?/do donors punish democratic decline?
  # Lit Review
    # Democratic backsliding
      # Background on what backsliding is/measurement
      # Levitsky, Ziblatt (2018)
        # Modern democratic backsliding typically comes via elected leaders gradually dismantling democratic institutions from within (executive aggrandizement)
        # Applicable if we want to focus on gradual decline 
      # Lührmann, Lindberg (2019)
        # Global pattern of democratic decline since the mid-2000s
        # Introduce “autocratization episodes” (periods of drops in democracy)
        # ** they define thresholds for what counts as a meaningful decline in VDEM scores 
        # Can help us construct the democratic decline variable
    # Donor-punishment 
      # Donors should – in theory – respond to the quality of governance 
      # Burnside, Dollar (2000)
        # Aid conditionality 
        # Foreign aid only promotes economic growth when recipient countries have good fiscal, monetary, and trade policies
        # Relevance: donors should be selective (but this paper says this conditionality is more about economic policy, not democracy specifically)
        # Use this article to establish the conditionality paradigm, then pivot to including democratic governance 
      # Crawford (2001)
        # Do donors actually follow through on political conditionality?
        # Looking at foreign aid and human rights & democratization
        # The practice of conditionality is cheap talk (donors threaten to cut aid but don’t usually follow through)
        # Relevance: highlights the gap between a stated policy and behavior (donors may claim to cut aid to countries that have democratically declined, but might not follow through)
      # Dietrich, Wright (2015)
        # Donors do respond to governance, but this changes based on the donor type
        # Bilateral vs multilateral
        # Distinguish between aid amounts and delivery channels
    # Norms vs interest 
      # When democracies decline, donors face a tough decision: should they uphold democratic norms and cut aid, or should they maintain a relationship because the country serves a strategic interest?
      # Dunning (2004)
        # Cold War vs post Cold War aid allocation
        # Strategic competitions led donors to overlook authoritarianism when geopolitical stakes were high
        # The Cold War opened space for conditionality, but not completely
        # Strategic interests never disappeared, they shifted
        # Application: historical anchor
        # ** The post Cold-War period is one where both democratic norms and strategic interests coexist
      # BDM, Smith (2009)
        # Drawing on selectorate theory
        # Donors rationally prefer giving aid to autocrats because they can be bought more cheaply
        # Small winning coalition (selectorate) requires less aid to stay loyal than a broad democratic electorate
        # Relevance: donors don’t fail to enforce conditionality because they are incompetent, rather they have systematic incentives not to
      # Wright (2009)
        # Aid can foster democratization under specific conditions
        # Aid flows to authoritarian regimes and helps them survive
        # Important: autocrats are not necessarily penalized in aid allocation (could be consistent with a null result)
  # Theory
    # Logic: 
      # Post Cold War donors have institutionalized democracy promotion norms
      # Democratic backsliding episodes are visible to donors, but strategic interests create competing pressures
      # H1: countries experiencing more democratic backsliding will receive less foreign aid in subsequent years
  # Data and Methods
    # DV: foreign aid
      # AidData
      # OECD DAC
        # Maybe easier to merge with VDEM?
    # IV: democratic backsliding
      # VDEM
        # We can use either the Liberal Democracy Index (v2x_libdem) or Electoral Democracy Index (v2x_polyarchy) to construct a backsliding variable
        # OR use VDEM’s ERT data set (Episodes of Regime Transformation) which already codes backsliding episodes
    # Potential controls: GDP/capita, population, trade openness, etc
    # Binary outcome but continuous treatment… → we could make DV binary and use a logit model (recode the DV as binary with some cutoff?)
  # Results and Discussion
    # Summary stats, regression results
    # Interpret (sign, magnitude, significance)
    # Discuss with respect to H1
  # Conclusion
    # Implications, limitations 
