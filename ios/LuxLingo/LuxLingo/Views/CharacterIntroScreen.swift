import SwiftUI

// MARK: - Character data

private struct Character: Identifiable {
    let id: String
    let name: String
    let assetName: String
    let ageLu: String        // e.g. "16 Joer al"
    let descriptionLu: String
    let descriptionEn: String
    let accentColor: Color
}

private let characters: [Character] = [
    Character(
        id: "marc",
        name: "Marc",
        assetName: "character_marc",
        ageLu: "8 Joer al",
        descriptionLu: "Marc ass 8 Joer al a wunnt zu Mecher. Hien ass e flinke Leefer an ass ëmmer séier ënnerwee. Hien spillt gär Foussball a léiert fläisseg Lëtzebuergesch fir seng Zukunft.",
        descriptionEn: "Marc is 8 years old and lives in Mecher. He is a nimble runner and is always on the move. He loves playing football and is diligently learning Luxembourgish for his future.",
        accentColor: .luxGreen
    ),
    Character(
        id: "anna",
        name: "Anna",
        assetName: "character_anna",
        ageLu: "11 Joer al",
        descriptionLu: "Anna ass 11 Joer al a kënnt vun Däitschland. Si ass dem Paul seng grouss Schwëster a spillt am léifsten mat hirem Hond Bello am Gaart. Wann si net spillt, liest si gär Bicher.",
        descriptionEn: "Anna is 11 years old and comes from Germany. She is Paul's big sister and loves playing with her dog Bello in the garden. When she isn't playing, she enjoys reading books.",
        accentColor: Color(red: 0.9, green: 0.4, blue: 0.4)
    ),
    Character(
        id: "paul",
        name: "Paul",
        assetName: "character_paul",
        ageLu: "12 Joer al",
        descriptionLu: "Paul ass 12 Joer al an ass aus Däitschland. Hien ass ëmmer voll Energie a huet et gär, mat sengem Vëlo duerch d'Duerf ze fueren an nei Saachen ze entdecken.",
        descriptionEn: "Paul is 12 years old and is from Germany. He is always full of energy and loves cycling through the village and discovering new things.",
        accentColor: .luxAmber
    ),
    Character(
        id: "lena",
        name: "Lena",
        assetName: "character_lena",
        ageLu: "11 Joer al",
        descriptionLu: "Lena ass 11 Joer al a kënnt aus der Belsch. Si ass eng ganz léif an hëllefsbereet Frëndin, déi moies fir jiddereen e waarme Frühstéck an der Kichen mécht.",
        descriptionEn: "Lena is 11 years old and comes from Belgium. She is a very kind and helpful friend who prepares a warm breakfast in the kitchen for everyone every morning.",
        accentColor: Color(red: 0.5, green: 0.3, blue: 0.8)
    ),
    Character(
        id: "claire",
        name: "Claire",
        assetName: "character_claire",
        ageLu: "11 Joer al",
        descriptionLu: "Claire ass 11 Joer al a d'Klass-Bescht an der Schoul. Si huet eng kleng Kaz a dréit ëmmer eng Tasch voll Bicher mat sech, well si Geschichten iwwer alles gär huet.",
        descriptionEn: "Claire is 11 years old and top of her class at school. She has a small cat and always carries a bag full of books with her because she loves stories more than anything.",
        accentColor: Color(red: 0.2, green: 0.6, blue: 0.8)
    ),
    Character(
        id: "natali",
        name: "Natali",
        assetName: "character_natali",
        ageLu: "5 Joer al",
        descriptionLu: "Natali ass eng 5 Joer al Nopesch, déi ganz neiergiereg ass a vill Froen stellt. Och wann si nach jonk ass, schwätzt si scho fléissend Lëtzebuergesch a probéiert hirem Papp d'Sprooch bäizebréngen.",
        descriptionEn: "Natali is a curious 5-year-old neighbor with a never-ending stream of questions. Despite her young age, she is already fluent in Luxembourgish and loves trying to teach her father the language every day.",
        accentColor: Color(red: 0.9, green: 0.4, blue: 0.7)
    ),
    Character(
        id: "mr_weiss",
        name: "Här Weiss",
        assetName: "character_mr_weiss",
        ageLu: "De Lëtzebuergesch-Léierer",
        descriptionLu: "Här Weiss ënnerstëtzt seng Schüler mat vill Gedold a Freed. Hien gleeft fest drun, datt jiddereen Lëtzebuergesch léiere kann, egal vu wou hie kënnt.",
        descriptionEn: "Mr. Weiss supports his students with plenty of patience and joy. He firmly believes that anyone can learn Luxembourgish, no matter where they come from.",
        accentColor: Color(red: 0.3, green: 0.5, blue: 0.3)
    ),
    Character(
        id: "bello",
        name: "Bello",
        assetName: "character_bello",
        ageLu: "De Familljenhond",
        descriptionLu: "Bello ass de treien Hond vun der Famill an dem Anna säi beschte Frënd. Hien ass ëmmer gutt gelaunt, wëll ëmmer spillen a freet sech iwwer all neie Mënsch.",
        descriptionEn: "Bello is the family's loyal dog and Anna's best friend. He is always in a good mood, always wants to play, and gets excited about every new person he meets.",
        accentColor: Color(red: 0.7, green: 0.5, blue: 0.2)
    ),
]

// MARK: - Screen

struct CharacterIntroScreen: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Meet the Characters")
                        .font(.title2).fontWeight(.bold)
                    Text("All example sentences in LuxLingo feature these characters. Get to know them — they'll feel like old friends.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 16)

                Divider().padding(.horizontal, 20)

                ForEach(characters) { char in
                    CharacterCard(character: char)
                    Divider().padding(.horizontal, 20)
                }

                Spacer().frame(height: 32)
            }
        }
    }
}

// MARK: - Character Card

private struct CharacterCard: View {
    let character: Character

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Portrait
            Group {
                if let uiImg = UIImage(named: character.assetName) {
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                } else {
                    Color(character.accentColor).opacity(0.15)
                }
            }
            .frame(width: 80, height: 130)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.08), radius: 4, y: 2)

            // Text
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(character.name)
                        .font(.headline)
                    Text(character.ageLu)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(character.accentColor.opacity(0.12))
                        .cornerRadius(8)
                }

                // Luxembourgish
                JustifiedText(text: character.descriptionLu,
                              uiFont: .preferredFont(forTextStyle: .subheadline),
                              uiColor: .label)

                // English translation
                HStack(alignment: .top, spacing: 4) {
                    Text("EN")
                        .font(.caption2).fontWeight(.semibold)
                        .foregroundColor(character.accentColor)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(character.accentColor.opacity(0.12))
                        .cornerRadius(4)
                        .fixedSize()
                    JustifiedText(text: character.descriptionEn,
                                  uiFont: .preferredFont(forTextStyle: .caption1),
                                  uiColor: .secondaryLabel)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}
