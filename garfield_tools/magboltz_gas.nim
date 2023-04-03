import std / [strutils, os, strformat, sequtils, math, options, strscans]
import pkg / unchained
import ./garfield

defUnit(V•cm⁻¹, toExport = true)
type
  GasMixture* = object
    gases*: seq[Gas]
    temperature* = (273.15 + 20.0).Kelvin
    pressure* = 787.6.Torr
    eField* = 700.0.V•cm⁻¹
  Gas* = object
    name*: string
    gId*: int # Magboltz/Degrad ID of the given gas
    perc*: float # percentage of this gas

proc getGasID*(gasname: string): int
proc initGasMixture*[P: Pressure](T: Kelvin,
                                  pressure: P,
                                  eField: V•cm⁻¹,
                                  gases: seq[Gas]): GasMixture =
  var sum = 0.0
  for g in gases:
    sum += g.perc
  if abs(1.0 - sum) > 1e-3:
    raise newException(ValueError, "Given gas mixture does not sum to 100% for " &
      "all contributions: " & $gases)
  result = GasMixture(temperature: T,
                      pressure: pressure.to(Torr),
                      eField: eField,
                      gases: gases)

proc initGas*(gas: string, percentage: float): Gas =
  result = Gas(name: gas,
               gId: getGasID(gas),
               perc: percentage)

proc initGasMixture*[P: Pressure](
  T: Kelvin,
  pressure: P,
  eField: V•cm⁻¹,
  gases: seq[string],
  percs: seq[float]): GasMixture =
  var gas = newSeq[Gas]()
  for (name, p) in zip(gases, percs):
    gas.add initGas(name, p)
  result = initGasMixture(T, pressure, eField, gas)

proc initGasMixture*[P: Pressure](
  T: Kelvin,
  pressure: P,
  eField: V•cm⁻¹,
  gases: varargs[(string, float)]): GasMixture =
  var gs = newSeq[string]()
  var ps = newSeq[float]()
  for (name, p) in gases:
    gs.add name
    ps.add p
  result = initGasMixture(T, pressure, eField, gs, ps)

import pkg / cppstl
proc setupMediumMagboltz*(gas: GasMixture): MediumMagboltz =
  #result = MediumMagboltz.init()
  ## XXX: modify this if we want to support more gases!
  result = MediumMagboltz.new()
  let g0 = gas.gases[0]
  let g1 = gas.gases[1]
  #result = MediumMagboltz.init(g0.name, g0.perc, g1.name, g1.perc)
  result.setComposition(g0.name, g0.perc * 100.0, g1.name, g1.perc * 100.0)
  result.setTemperature(gas.temperature.float)
  result.setPressure(gas.pressure.float)
  result.initialise(true)

proc genGasFileName*(gas: GasMixture, eMin, eMax: float, nE, numCollisions: int): string =
  ## XXX: better would be to force shorthands of gas names!
  for i, g in gas.gases:
    let perc = (g.perc * 100.0).round.int
    result.add &"{g.name}_{perc}"
    if i < gas.gases.high:
      result.add "_"
  result.add &"_T_{gas.temperature.float}_P_{gas.pressure.float}_eMin_{eMin:.2f}_eMax_{eMax:.2f}_nE_{nE}_ncoll_{numCollisions}.gas"

proc generateGasFile*(gas: GasMixture,
                      gasFileDir: string,
                      eMin, eMax = 0.0.V•cm⁻¹,
                      nE = 100,
                      numCollisions = 100
                     ): string =
  ## Generates the gas file for the given mixture and stores it in the
  ## `gasFileDir`
  var mbGas = setupMediumMagboltz(gas)
  # Set the field range to be covered by the gas table.

  # generate up to twice the desired field
  const useLog = false
  let eMin = if eMin > 0.0.V•cm⁻¹: eMin.float else: 0.0
  let eMax = if eMax > 0.0.V•cm⁻¹: eMax.float else: 2.0 * gas.eField.float
  mbGas.setFieldGrid(eMin, eMax, nE, useLog)

  # Run Magboltz to generate the gas table.
  mbGas.generateGasTable(numCollisions)
  # Save the table
  result = genGasFileName(gas, eMin, eMax, nE, numCollisions)
  discard existsOrCreateDir(gasFileDir)
  mbGas.writeGasFile(gasFileDir / result)

proc findMatchingGasFile(gas: GasMixture, gasFileDir: string): Option[string] =
  ## Attempts to locate a gas file for the input gas that matches the
  ## mixture. This means finding a file with same temperature, pressure
  ## and electric field.
  proc isClose(a, b: float): bool = abs(a - b) < 1e-3
  for file in walkFiles(gasFileDir & "*.gas"):
    let name = file.extractFilename()
    let (match, g1, p1, g2, p2, T, P, eMin, eMax, nE, nc) = name.scanTuple("$w_$f_$w_$f_T_$f_P_$f_eMin_$f_eMax_$f_nE_$i_ncoll_$i.gas")
    if match and
       g1 == gas.gases[0].name          and
       p1.isClose(gas.gases[0].perc)    and
       g2 == gas.gases[1].name          and
       p2.isClose(gas.gases[0].perc)    and
       T.isClose(gas.temperature.float) and
       P.isClose(gas.pressure.float)    and
       gas.eField.float in eMin .. eMax:
      return some(name)

proc readOrGenGasFile*(gas: GasMixture, gasFile, gasFileDir: string): string =
  ## Attempts to read a given gas file (or from the resources directory)
  ## otherwise will generate a gas file
  if gasFile.len > 0:
    result = gasFile
  else:
    let gasFileOpt = findMatchingGasFile(gas, gasFileDir)
    if gasFileOpt.isSome:
      result = gasFileDir / gasFileOpt.get
    else:
      # need to generate a gas file using Garfield++
      result = gasFileDir / generateGasFile(gas, gasFileDir)

proc getGasID*(gasname: string): int =
  ## Get the magboltz / degrad ID for a gas based on a Garfield++ gas name
  case gasname
  of "CF4":                      result = 1
  of "Ar", "Argon":              result = 2
  of "He", "Helium":             result = 3
  of "He3", "Helium-3":          result = 4
  of "Ne", "Neon":               result = 5
  of "Kr", "Krypton":            result = 6
  of "Xe", "Xenon":              result = 7
  of "CH4", "Methane":           result = 8
  of "Ethane":                   result = 9
  of "Propane":                  result = 10
  of "Isobutane":                result = 11
  of "CO2":                      result = 12
  of "Neo-Pentane":              result = 13
  of "H2O", "Water":             result = 14
  of "O", "Oxygen":              result = 15
  of "N", "Nitrogen":            result = 16
  of "Nitric Oxide":             result = 17
  of "Nitrous Oxide":            result = 18
  of "Ethene":                   result = 19
  of "Acetylene":                result = 20
  of "H2":                       result = 21
  of "Hydrogen":                 result = 21
  of "D2", "Deuterium":          result = 22
  of "CO", "Carbon Monoxide":    result = 23
  of "Methylal":                 result = 24
  of "DME":                      result = 25
  of "Reid Step Model":          result = 26
  of "Maxwell Model":            result = 27
  of "Reid Ramp Model":          result = 28
  of "C2F6":                     result = 29
  of "SF6":                      result = 30
  of "NH3", "Ammonia":           result = 31
  of "C3H6":                     result = 32
  of "Propene":                  result = 32
  of "Cylopropane":              result = 33
  of "CH3OH", "Methanol":        result = 34
  of "C2H5OH", "Ethanol":        result = 35
  of "C3H7OH", "Iso-Propanol":   result = 36
  of "Cs", "Cesium":             result = 37
  of "F", "Flourine":            result = 38
  of "CS2":                      result = 39
  of "COS":                      result = 40
  of "CD4":                      result = 41
  of "BF3", "Boron-Triflouride": result = 42
  of "C2HF5", "C2H2F4":          result = 43 ## XXX: these are the same?
  of "TMA":                      result = 44
  of "N-Propanol":               result = 46 ## XXX: uhhh, in the C code this is *also* `"C3H7OH"`, like `36`!
  of "CHF3":                     result = 50
  of "CF3BR":                    result = 51
  of "C3F8":                     result = 52
  of "O3", "Ozone":              result = 53
  of "Hg", "Mercury":            result = 54
  of "H2S":                      result = 55
  of "N-Butane":                 result = 56
  of "N-Pentane":                result = 57
  of "CCL4":                     result = 61
  else:
    raise newException(ValueError, "Invalid gas: " & $gasname)

proc main(gases: seq[string],
          percs: seq[float],
          temperature: Kelvin,
          pressure: MilliBar,
          eMin, eMax: V•cm⁻¹,
          nE = 100,
          numCollisions = 100,
          outdir = "resources/",
          outname = "") =
  let gasMixture = initGasMixture(temperature, pressure, 0.0.V•cm⁻¹,
                                  gases, percs)

  let outfile = generateGasFile(gasMixture, outdir, eMin, eMax,
                                nE = nE, numCollisions = numCollisions)
  echo "Wrote gas file: ", outdir / outfile

when isMainModule:
  import unchained / cligenParseUnits

  import cligen
  dispatch(main, help = {
    "gases" : "Sequence of all gases to use",
    "percs" : "The percentages of all gases to use, must sum to 1.",
    "temperature" : "Temperature in Kelvin (!) of the gas",
    "pressure" : "Pressure of the gas in milli bar",
    "eMin" : "Minimum electric field to generate gas file for",
    "eMax" : "Maximum electric field to generate gas file for",
    "numCollisions" : "Number of collisions to use",
    "nE" : "Number of steps between eMin and eMax",
    "outdir" : "The location where gas file will be stored",
    "outname" : "Override the default output file name"
  })
