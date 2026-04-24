class ADCNormalizer {
  static double normalizeToADC(
    double conductivity,
    double goldConductivity,
    double goldADC,
  ) {
    if (goldConductivity == 0) return 0;
    return (conductivity / goldConductivity) * goldADC;
  }
}