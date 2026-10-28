# Meal photo model (not included)

The app expects a Core ML image classifier named `DishClassifier.mlmodel` in `Resources/`.
Without it, the meal-photo screen says it cannot recognise food and shows the dish list. Nothing breaks.

## Label names

One class per dish, named exactly like the `id` in `Models/Dish.swift`
(`steamed_rice`, `char_siu_rice`, `wonton_noodles`, ...). Do not rename a label without renaming the dish.

## Train it (Mac, Create ML app, no code)

1. Open Create ML (Xcode menu, Open Developer Tool) and choose Image Classifier.
2. Make a folder per dish id, each with at least 50 to 100 photos. Vary the plate, the light, the angle and the restaurant. Photos you take yourselves, or ones with a licence that allows use, are best.
3. Hold back about 20% as a test set. Look at which dishes get confused (for example 叉燒飯 and 燒鵝飯) before trusting it.
4. Export the `.mlmodel`, name it `DishClassifier`, drag it into `Resources/`, and rebuild.

## Before showing anyone

- Test with photos the model never saw, taken on an iPhone, in real restaurant light.
- Tune `DishDecision.confirmAt` / `chooseAt` against those photos. The app always asks "is it this?" before using a guess, so a wrong guess costs one tap, not a wrong result.
- Replace every placeholder number in `Dish.swift` with values a dietitian signs off.
- Say clearly in the competition write-up that the list is closed (about 24 dishes) and that anything else goes to the list.
