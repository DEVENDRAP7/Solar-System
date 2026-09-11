import 'celestial_body.dart';
import 'orbital_elements.dart';

/// The bodies in the simulation.
///
/// Orbital elements are the Jet Propulsion Laboratory's approximate elements
/// for the major planets, referred to the J2000 ecliptic, with rates per Julian
/// century. They are intended for the interval 1800-2050, where they place the
/// planets to within a few arcminutes.
///
/// Physical data (radii, rotation periods, axial tilts) comes from the NASA
/// planetary fact sheets. Radii are kept in step with the generated models by
/// `test/body_catalog_test.dart`, which checks them against
/// `assets/data/bodies.json`.
class BodyCatalog {
  const BodyCatalog._();

  static const CelestialBody sun = CelestialBody(
    key: 'sun',
    label: 'Sun',
    type: BodyType.star,
    radiusKm: 696340.0,
    rotationHours: 609.12,
    axialTiltDeg: 7.25,
    gravity: 274.0,
    meanTemperatureC: 5505.0,
    description:
        'The Sun holds 99.86% of the mass of the solar system. Its core fuses '
        '600 million tonnes of hydrogen every second, and the light that '
        'reaches you left its surface about eight minutes ago.',
  );

  static const CelestialBody mercury = CelestialBody(
    key: 'mercury',
    label: 'Mercury',
    type: BodyType.terrestrial,
    radiusKm: 2439.7,
    rotationHours: 1407.6,
    axialTiltDeg: 0.034,
    gravity: 3.7,
    meanTemperatureC: 167.0,
    description:
        'The smallest planet and the fastest, rounding the Sun every 88 days. '
        'With almost no atmosphere to hold heat, its surface swings between '
        '430°C in daylight and -180°C at night.',
    elements: OrbitalElements(
      semiMajorAxisAu: 0.38709927,
      eccentricity: 0.20563593,
      inclinationDeg: 7.00497902,
      meanLongitudeDeg: 252.25032350,
      longitudeOfPerihelionDeg: 77.45779628,
      longitudeOfAscendingNodeDeg: 48.33076593,
      semiMajorAxisRate: 0.00000037,
      eccentricityRate: 0.00001906,
      inclinationRate: -0.00594749,
      meanLongitudeRate: 149472.67411175,
      longitudeOfPerihelionRate: 0.16047689,
      longitudeOfAscendingNodeRate: -0.12534081,
    ),
  );

  static const CelestialBody venus = CelestialBody(
    key: 'venus',
    label: 'Venus',
    type: BodyType.terrestrial,
    radiusKm: 6051.8,
    rotationHours: -5832.5,
    axialTiltDeg: 177.36,
    gravity: 8.87,
    meanTemperatureC: 464.0,
    description:
        'Venus turns backwards, and so slowly that its day is longer than its '
        'year. A thick carbon dioxide atmosphere traps heat well enough to melt '
        'lead at the surface.',
    elements: OrbitalElements(
      semiMajorAxisAu: 0.72333566,
      eccentricity: 0.00677672,
      inclinationDeg: 3.39467605,
      meanLongitudeDeg: 181.97909950,
      longitudeOfPerihelionDeg: 131.60246718,
      longitudeOfAscendingNodeDeg: 76.67984255,
      semiMajorAxisRate: 0.00000390,
      eccentricityRate: -0.00004107,
      inclinationRate: -0.00078890,
      meanLongitudeRate: 58517.81538729,
      longitudeOfPerihelionRate: 0.00268329,
      longitudeOfAscendingNodeRate: -0.27769418,
    ),
  );

  static const CelestialBody earth = CelestialBody(
    key: 'earth',
    label: 'Earth',
    type: BodyType.terrestrial,
    radiusKm: 6371.0,
    rotationHours: 23.9345,
    axialTiltDeg: 23.44,
    gravity: 9.807,
    meanTemperatureC: 15.0,
    moonCount: 1,
    description:
        'The only place known to hold liquid water at the surface, and the only '
        'one known to hold life. Its 23.4° tilt is what gives the planet '
        'seasons.',
    elements: OrbitalElements(
      semiMajorAxisAu: 1.00000261,
      eccentricity: 0.01671123,
      inclinationDeg: -0.00001531,
      meanLongitudeDeg: 100.46457166,
      longitudeOfPerihelionDeg: 102.93768193,
      longitudeOfAscendingNodeDeg: 0.0,
      semiMajorAxisRate: 0.00000562,
      eccentricityRate: -0.00004392,
      inclinationRate: -0.01294668,
      meanLongitudeRate: 35999.37244981,
      longitudeOfPerihelionRate: 0.32327364,
      longitudeOfAscendingNodeRate: 0.0,
    ),
  );

  static const CelestialBody moon = CelestialBody(
    key: 'moon',
    label: 'Moon',
    type: BodyType.moon,
    radiusKm: 1737.4,
    rotationHours: 655.72,
    axialTiltDeg: 6.68,
    gravity: 1.62,
    meanTemperatureC: -20.0,
    parentKey: 'earth',
    orbitalPeriodDaysOverride: 27.321582,
    description:
        'Locked in step with Earth, the Moon shows us one face and keeps the '
        'other turned away. It drifts about 3.8 cm further from us each year.',
    // Mean elements relative to Earth. The real lunar orbit is perturbed
    // heavily by the Sun; this reproduces the month and the 5.1° inclination
    // but not the finer wobbles.
    elements: OrbitalElements(
      semiMajorAxisAu: 0.00257,
      eccentricity: 0.0549,
      inclinationDeg: 5.145,
      meanLongitudeDeg: 218.316,
      longitudeOfPerihelionDeg: 83.353,
      longitudeOfAscendingNodeDeg: 125.045,
      meanLongitudeRate: 481267.881,
      longitudeOfPerihelionRate: 4069.0137,
      longitudeOfAscendingNodeRate: -1934.1362,
    ),
  );

  static const CelestialBody mars = CelestialBody(
    key: 'mars',
    label: 'Mars',
    type: BodyType.terrestrial,
    radiusKm: 3389.5,
    rotationHours: 24.6229,
    axialTiltDeg: 25.19,
    gravity: 3.71,
    meanTemperatureC: -65.0,
    moonCount: 2,
    description:
        'Rust in the soil gives Mars its colour. It carries the tallest volcano '
        'in the solar system, Olympus Mons, three times the height of Everest.',
    elements: OrbitalElements(
      semiMajorAxisAu: 1.52371034,
      eccentricity: 0.09339410,
      inclinationDeg: 1.84969142,
      meanLongitudeDeg: -4.55343205,
      longitudeOfPerihelionDeg: -23.94362959,
      longitudeOfAscendingNodeDeg: 49.55953891,
      semiMajorAxisRate: 0.00001847,
      eccentricityRate: 0.00007882,
      inclinationRate: -0.00813131,
      meanLongitudeRate: 19140.30268499,
      longitudeOfPerihelionRate: 0.44441088,
      longitudeOfAscendingNodeRate: -0.29257343,
    ),
  );

  static const CelestialBody jupiter = CelestialBody(
    key: 'jupiter',
    label: 'Jupiter',
    type: BodyType.gasGiant,
    radiusKm: 69911.0,
    rotationHours: 9.9250,
    axialTiltDeg: 3.13,
    gravity: 24.79,
    meanTemperatureC: -110.0,
    moonCount: 95,
    description:
        'Jupiter is more massive than every other planet combined, and spins '
        'once in under ten hours. The Great Red Spot is a storm that has been '
        'turning for at least 150 years.',
    elements: OrbitalElements(
      semiMajorAxisAu: 5.20288700,
      eccentricity: 0.04838624,
      inclinationDeg: 1.30439695,
      meanLongitudeDeg: 34.39644051,
      longitudeOfPerihelionDeg: 14.72847983,
      longitudeOfAscendingNodeDeg: 100.47390909,
      semiMajorAxisRate: -0.00011607,
      eccentricityRate: -0.00013253,
      inclinationRate: -0.00183714,
      meanLongitudeRate: 3034.74612775,
      longitudeOfPerihelionRate: 0.21252668,
      longitudeOfAscendingNodeRate: 0.20469106,
    ),
  );

  static const CelestialBody saturn = CelestialBody(
    key: 'saturn',
    label: 'Saturn',
    type: BodyType.gasGiant,
    radiusKm: 58232.0,
    rotationHours: 10.656,
    axialTiltDeg: 26.73,
    gravity: 10.44,
    meanTemperatureC: -140.0,
    moonCount: 146,
    ringModelAsset: 'assets/models/saturn_rings.glb',
    ringInnerRadii: 1.24,
    ringOuterRadii: 2.27,
    description:
        'Saturn is less dense than water. Its rings span tens of thousands of '
        'kilometres but are only about ten metres thick.',
    elements: OrbitalElements(
      semiMajorAxisAu: 9.53667594,
      eccentricity: 0.05386179,
      inclinationDeg: 2.48599187,
      meanLongitudeDeg: 49.95424423,
      longitudeOfPerihelionDeg: 92.59887831,
      longitudeOfAscendingNodeDeg: 113.66242448,
      semiMajorAxisRate: -0.00125060,
      eccentricityRate: -0.00050991,
      inclinationRate: 0.00193609,
      meanLongitudeRate: 1222.49362201,
      longitudeOfPerihelionRate: -0.41897216,
      longitudeOfAscendingNodeRate: -0.28867794,
    ),
  );

  static const CelestialBody uranus = CelestialBody(
    key: 'uranus',
    label: 'Uranus',
    type: BodyType.iceGiant,
    radiusKm: 25362.0,
    rotationHours: -17.24,
    axialTiltDeg: 97.77,
    gravity: 8.87,
    meanTemperatureC: -195.0,
    moonCount: 28,
    description:
        'Uranus is tipped almost onto its side, so it rolls along its orbit. '
        'Each pole spends 42 years in sunlight, then 42 years in darkness.',
    elements: OrbitalElements(
      semiMajorAxisAu: 19.18916464,
      eccentricity: 0.04725744,
      inclinationDeg: 0.77263783,
      meanLongitudeDeg: 313.23810451,
      longitudeOfPerihelionDeg: 170.95427630,
      longitudeOfAscendingNodeDeg: 74.01692503,
      semiMajorAxisRate: -0.00196176,
      eccentricityRate: -0.00004397,
      inclinationRate: -0.00242939,
      meanLongitudeRate: 428.48202785,
      longitudeOfPerihelionRate: 0.40805281,
      longitudeOfAscendingNodeRate: 0.04240589,
    ),
  );

  static const CelestialBody neptune = CelestialBody(
    key: 'neptune',
    label: 'Neptune',
    type: BodyType.iceGiant,
    radiusKm: 24622.0,
    rotationHours: 16.11,
    axialTiltDeg: 28.32,
    gravity: 11.15,
    meanTemperatureC: -200.0,
    moonCount: 16,
    description:
        'The most distant planet, and the windiest: gusts reach 2,000 km/h. It '
        'was found by mathematics before anyone saw it, predicted from wobbles '
        "in Uranus's orbit.",
    elements: OrbitalElements(
      semiMajorAxisAu: 30.06992276,
      eccentricity: 0.00859048,
      inclinationDeg: 1.77004347,
      meanLongitudeDeg: -55.12002969,
      longitudeOfPerihelionDeg: 44.96476227,
      longitudeOfAscendingNodeDeg: 131.78422574,
      semiMajorAxisRate: 0.00026291,
      eccentricityRate: 0.00005105,
      inclinationRate: 0.00035372,
      meanLongitudeRate: 218.45945325,
      longitudeOfPerihelionRate: -0.32241464,
      longitudeOfAscendingNodeRate: -0.00508664,
    ),
  );

  /// Kilometres in an astronomical unit.
  static const double _kmPerAu = 1.495978707e8;

  /// Build a moon from the numbers moons are actually published with: an
  /// orbital radius in kilometres and a period in days.
  ///
  /// A moon orbits its planet's equator rather than the ecliptic, so its
  /// inclination is given against that equator and the planet's axial tilt is
  /// added on. This is why Uranus's moons come out orbiting nearly upright:
  /// the planet is tipped 98 degrees and its moons went with it.
  static CelestialBody _moon({
    required String key,
    required String label,
    required String parentKey,
    required double semiMajorAxisKm,
    required double periodDays,
    required double radiusKm,
    required double eccentricity,
    required double inclinationToEquatorDeg,
    required double parentTiltDeg,
    required double meanLongitudeDeg,
    required String description,
    double? eclipticInclinationDeg,
    double? gravity,
    double? meanTemperatureC,
  }) {
    return CelestialBody(
      key: key,
      label: label,
      type: BodyType.moon,
      radiusKm: radiusKm,
      // Every one of these is tidally locked, turning once per orbit.
      rotationHours: periodDays * 24.0,
      axialTiltDeg: 0.0,
      parentKey: parentKey,
      orbitalPeriodDaysOverride: periodDays,
      gravity: gravity,
      meanTemperatureC: meanTemperatureC,
      description: description,
      elements: OrbitalElements(
        semiMajorAxisAu: semiMajorAxisKm / _kmPerAu,
        eccentricity: eccentricity,
        inclinationDeg:
            eclipticInclinationDeg ?? (parentTiltDeg + inclinationToEquatorDeg),
        meanLongitudeDeg: meanLongitudeDeg,
        longitudeOfPerihelionDeg: 0.0,
        // The node is set a quarter turn round so the orbit tilts the same way
        // the planet leans, keeping moons over their planet's equator.
        longitudeOfAscendingNodeDeg: 90.0,
        meanLongitudeRate: 360.0 / periodDays * 36525.0,
      ),
    );
  }

  static final List<CelestialBody> moons = <CelestialBody>[
    _moon(
      key: 'phobos',
      label: 'Phobos',
      parentKey: 'mars',
      semiMajorAxisKm: 9376,
      periodDays: 0.31891,
      radiusKm: 11.27,
      eccentricity: 0.0151,
      inclinationToEquatorDeg: 1.093,
      parentTiltDeg: 25.19,
      meanLongitudeDeg: 24,
      gravity: 0.0057,
      description:
          'Phobos circles Mars three times a day, faster than the '
          'planet turns, so it rises in the west. It is drifting inward and '
          'will break apart in some tens of millions of years.',
    ),
    _moon(
      key: 'deimos',
      label: 'Deimos',
      parentKey: 'mars',
      semiMajorAxisKm: 23463,
      periodDays: 1.26244,
      radiusKm: 6.2,
      eccentricity: 0.00033,
      inclinationToEquatorDeg: 1.788,
      parentTiltDeg: 25.19,
      meanLongitudeDeg: 210,
      gravity: 0.003,
      description:
          'The smaller and outer of Mars\'s two moons, barely 12 km '
          'across. From the surface it would look like a bright star.',
    ),

    _moon(
      key: 'io',
      label: 'Io',
      parentKey: 'jupiter',
      semiMajorAxisKm: 421700,
      periodDays: 1.769138,
      radiusKm: 1821.6,
      eccentricity: 0.0041,
      inclinationToEquatorDeg: 0.05,
      parentTiltDeg: 3.13,
      meanLongitudeDeg: 42,
      gravity: 1.796,
      meanTemperatureC: -163,
      description:
          'The most volcanic world in the solar system. Squeezed by '
          'Jupiter and its neighbours, Io turns itself inside out, throwing '
          'sulphur hundreds of kilometres above the surface.',
    ),
    _moon(
      key: 'europa',
      label: 'Europa',
      parentKey: 'jupiter',
      semiMajorAxisKm: 671034,
      periodDays: 3.551181,
      radiusKm: 1560.8,
      eccentricity: 0.009,
      inclinationToEquatorDeg: 0.47,
      parentTiltDeg: 3.13,
      meanLongitudeDeg: 168,
      gravity: 1.314,
      meanTemperatureC: -171,
      description:
          'Under a shell of cracked ice lies a salt water ocean '
          'holding more water than every ocean on Earth combined. It is one '
          'of the best places to look for life.',
    ),
    _moon(
      key: 'ganymede',
      label: 'Ganymede',
      parentKey: 'jupiter',
      semiMajorAxisKm: 1070412,
      periodDays: 7.154553,
      radiusKm: 2634.1,
      eccentricity: 0.0013,
      inclinationToEquatorDeg: 0.2,
      parentTiltDeg: 3.13,
      meanLongitudeDeg: 291,
      gravity: 1.428,
      meanTemperatureC: -163,
      description:
          'The largest moon in the solar system, bigger than '
          'Mercury, and the only one with a magnetic field of its own.',
    ),
    _moon(
      key: 'callisto',
      label: 'Callisto',
      parentKey: 'jupiter',
      semiMajorAxisKm: 1882709,
      periodDays: 16.689018,
      radiusKm: 2410.3,
      eccentricity: 0.0074,
      inclinationToEquatorDeg: 0.192,
      parentTiltDeg: 3.13,
      meanLongitudeDeg: 87,
      gravity: 1.235,
      meanTemperatureC: -139,
      description:
          'The most heavily cratered object known. Its surface has '
          'gone essentially unchanged for four billion years.',
    ),

    _moon(
      key: 'mimas',
      label: 'Mimas',
      parentKey: 'saturn',
      semiMajorAxisKm: 185539,
      periodDays: 0.942422,
      radiusKm: 198.2,
      eccentricity: 0.0196,
      inclinationToEquatorDeg: 1.574,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 15,
      gravity: 0.064,
      description:
          'One vast crater, Herschel, spans a third of its width. '
          'The impact nearly split the moon apart.',
    ),
    _moon(
      key: 'enceladus',
      label: 'Enceladus',
      parentKey: 'saturn',
      semiMajorAxisKm: 237948,
      periodDays: 1.370218,
      radiusKm: 252.1,
      eccentricity: 0.0047,
      inclinationToEquatorDeg: 0.009,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 133,
      gravity: 0.113,
      meanTemperatureC: -198,
      description:
          'Jets of water vapour erupt from cracks at its south '
          'pole, feeding one of Saturn\'s rings. There is an ocean beneath '
          'the ice.',
    ),
    _moon(
      key: 'tethys',
      label: 'Tethys',
      parentKey: 'saturn',
      semiMajorAxisKm: 294619,
      periodDays: 1.887802,
      radiusKm: 531.1,
      eccentricity: 0.0001,
      inclinationToEquatorDeg: 1.091,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 254,
      gravity: 0.146,
      description:
          'Almost pure water ice, and cut by Ithaca Chasma, a '
          'canyon running most of the way around it.',
    ),
    _moon(
      key: 'dione',
      label: 'Dione',
      parentKey: 'saturn',
      semiMajorAxisKm: 377396,
      periodDays: 2.736915,
      radiusKm: 561.4,
      eccentricity: 0.0022,
      inclinationToEquatorDeg: 0.028,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 61,
      gravity: 0.232,
      description:
          'Bright ice cliffs streak its trailing side, cracks in '
          'the crust caught in sunlight.',
    ),
    _moon(
      key: 'rhea',
      label: 'Rhea',
      parentKey: 'saturn',
      semiMajorAxisKm: 527108,
      periodDays: 4.518212,
      radiusKm: 763.8,
      eccentricity: 0.0013,
      inclinationToEquatorDeg: 0.331,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 189,
      gravity: 0.264,
      description:
          'Saturn\'s second largest moon, a cratered ball of ice '
          'and rock with a tenuous oxygen atmosphere.',
    ),
    _moon(
      key: 'titan',
      label: 'Titan',
      parentKey: 'saturn',
      semiMajorAxisKm: 1221870,
      periodDays: 15.945421,
      radiusKm: 2574.7,
      eccentricity: 0.0288,
      inclinationToEquatorDeg: 0.348,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 312,
      gravity: 1.352,
      meanTemperatureC: -179,
      description:
          'The only moon with a thick atmosphere, and the only '
          'world besides Earth with liquid on its surface — rivers and seas '
          'of methane under an orange haze.',
    ),
    _moon(
      key: 'iapetus',
      label: 'Iapetus',
      parentKey: 'saturn',
      semiMajorAxisKm: 3560820,
      periodDays: 79.3215,
      radiusKm: 734.5,
      eccentricity: 0.0286,
      inclinationToEquatorDeg: 15.47,
      parentTiltDeg: 26.73,
      meanLongitudeDeg: 98,
      gravity: 0.223,
      description:
          'One side is as dark as coal, the other as bright as '
          'snow, and a ridge of mountains runs along its equator.',
    ),

    _moon(
      key: 'miranda',
      label: 'Miranda',
      parentKey: 'uranus',
      semiMajorAxisKm: 129390,
      periodDays: 1.413479,
      radiusKm: 235.8,
      eccentricity: 0.0013,
      inclinationToEquatorDeg: 4.232,
      parentTiltDeg: 97.77,
      meanLongitudeDeg: 71,
      gravity: 0.079,
      description:
          'A jumble of terrain that looks assembled rather than '
          'formed, with cliffs twenty kilometres high.',
    ),
    _moon(
      key: 'ariel',
      label: 'Ariel',
      parentKey: 'uranus',
      semiMajorAxisKm: 190900,
      periodDays: 2.520379,
      radiusKm: 578.9,
      eccentricity: 0.0012,
      inclinationToEquatorDeg: 0.26,
      parentTiltDeg: 97.77,
      meanLongitudeDeg: 199,
      gravity: 0.269,
      description:
          'The brightest of Uranus\'s moons, its surface cut by '
          'valleys that were once flooded by ice.',
    ),
    _moon(
      key: 'umbriel',
      label: 'Umbriel',
      parentKey: 'uranus',
      semiMajorAxisKm: 266000,
      periodDays: 4.144177,
      radiusKm: 584.7,
      eccentricity: 0.0039,
      inclinationToEquatorDeg: 0.128,
      parentTiltDeg: 97.77,
      meanLongitudeDeg: 33,
      gravity: 0.2,
      description:
          'The darkest of the major Uranian moons, marked by a '
          'bright ring of unknown origin nicknamed the fluorescent cheerio.',
    ),
    _moon(
      key: 'titania',
      label: 'Titania',
      parentKey: 'uranus',
      semiMajorAxisKm: 436300,
      periodDays: 8.705872,
      radiusKm: 788.4,
      eccentricity: 0.0011,
      inclinationToEquatorDeg: 0.34,
      parentTiltDeg: 97.77,
      meanLongitudeDeg: 155,
      gravity: 0.379,
      description:
          'The largest moon of Uranus, scarred by canyons formed as '
          'its interior froze and expanded.',
    ),
    _moon(
      key: 'oberon',
      label: 'Oberon',
      parentKey: 'uranus',
      semiMajorAxisKm: 583519,
      periodDays: 13.463239,
      radiusKm: 761.4,
      eccentricity: 0.0014,
      inclinationToEquatorDeg: 0.058,
      parentTiltDeg: 97.77,
      meanLongitudeDeg: 278,
      gravity: 0.346,
      description:
          'The outermost large Uranian moon, its old cratered '
          'surface stained with dark material.',
    ),

    _moon(
      key: 'proteus',
      label: 'Proteus',
      parentKey: 'neptune',
      semiMajorAxisKm: 117647,
      periodDays: 1.122315,
      radiusKm: 210.0,
      eccentricity: 0.00053,
      inclinationToEquatorDeg: 0.026,
      parentTiltDeg: 28.32,
      meanLongitudeDeg: 4,
      gravity: 0.07,
      description:
          'About as large as a body can be without gravity pulling '
          'it into a sphere, which is why it is distinctly boxy.',
    ),
    _moon(
      key: 'triton',
      label: 'Triton',
      parentKey: 'neptune',
      semiMajorAxisKm: 354759,
      periodDays: 5.876854,
      radiusKm: 1353.4,
      eccentricity: 0.000016,
      inclinationToEquatorDeg: 156.885,
      parentTiltDeg: 28.32,
      eclipticInclinationDeg: 130.0,
      meanLongitudeDeg: 246,
      gravity: 0.779,
      meanTemperatureC: -235,
      description:
          'Triton orbits backwards, which means Neptune captured it '
          'rather than forming with it. Nitrogen geysers erupt from its pink '
          'polar cap, and it is slowly spiralling in.',
    ),
  ];

  /// The Sun and the planets, in order outward.
  static const List<CelestialBody> planetsAndSun = <CelestialBody>[
    sun,
    mercury,
    venus,
    earth,
    moon,
    mars,
    jupiter,
    saturn,
    uranus,
    neptune,
  ];

  /// Every body: the Sun, the planets and their moons.
  static final List<CelestialBody> all = <CelestialBody>[
    ...planetsAndSun,
    ...moons,
  ];

  /// The planets alone, in order outward from the Sun.
  static List<CelestialBody> get planets =>
      all.where((CelestialBody body) => body.orbitsSun).toList();

  static CelestialBody? byKey(String key) {
    for (final CelestialBody body in all) {
      if (body.key == key) {
        return body;
      }
    }
    return null;
  }
}
